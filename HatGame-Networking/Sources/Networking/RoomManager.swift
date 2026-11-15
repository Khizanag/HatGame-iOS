//
//  RoomManager.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import FirebaseDatabase
import Foundation
import Observation

/// Where this device stands with the room it observes.
public enum RoomConnectionState: Equatable, Sendable {
    /// Not in a room.
    case idle
    /// Observing, waiting for the first snapshot.
    case joining
    /// Receiving snapshots.
    case live
    /// The room disappeared — the host closed it.
    case closed
    /// The room exists but a newer build wrote data this one cannot read.
    case unsupported
}

@MainActor
@Observable
open class RoomManager {
    public internal(set) var room: GameRoom?
    public internal(set) var currentPlayerId: String?
    public internal(set) var isConnected: Bool = false
    public internal(set) var connectionState: RoomConnectionState = .idle

    private let firebaseService = FirebaseService.shared
    /// Tracked apart from `room`, which is nil before the first snapshot and
    /// after the room is deleted — exactly when the observer still needs
    /// removing.
    @ObservationIgnored private var observedRoomId: String?
    @ObservationIgnored private var roomObserverHandle: DatabaseHandle?
    /// Set while this device deletes or leaves the room, so its own write is
    /// not mistaken for the host closing it.
    @ObservationIgnored private var isLeaving = false
    /// `.info/connected` observer that keeps this player's `isConnected`
    /// accurate, so the host can cover for an explainer who drops out.
    @ObservationIgnored private var connectivityHandle: DatabaseHandle?
    /// Stable per-device UUID kept in UserDefaults so reconnects map back
    /// to the same player record.
    internal var deviceId: String

    public var isHost: Bool {
        room?.hostId == currentPlayerId
    }

    public var currentPlayer: OnlinePlayer? {
        guard let playerId = currentPlayerId else { return nil }
        return room?.players.first { $0.id == playerId }
    }

    public var currentTeam: OnlineTeam? {
        guard let teamId = currentPlayer?.teamId else { return nil }
        return room?.teams.first { $0.id == teamId }
    }

    public init() {
        self.deviceId = Self.getOrCreateDeviceId()
    }

    isolated deinit {
        if let roomObserverHandle, let observedRoomId {
            firebaseService.removeObserver(handle: roomObserverHandle, forRoomId: observedRoomId)
        }
        if let connectivityHandle {
            firebaseService.removeConnectionObserver(connectivityHandle)
        }
    }

    // MARK: - Room Creation
    /// Draws codes until one is free. With 32^6 codes a collision is rare, so
    /// a handful of attempts is plenty.
    open func createRoom(hostName: String, settings: GameSettings) async throws -> String {
        let host = OnlinePlayer(
            deviceId: deviceId,
            name: hostName,
            isReady: true
        )

        for _ in 0..<5 {
            let room = GameRoom(
                id: RoomCode.random(),
                hostId: host.id,
                status: .waiting,
                settings: settings,
                players: [host]
            )
            guard try await firebaseService.createRoom(room) else { continue }
            self.currentPlayerId = host.id
            startObservingRoom(id: room.id)
            return room.id
        }
        throw NetworkingError.failedToGenerateRoomCode
    }

    // MARK: - Room Joining
    open func joinRoom(code: String, playerName: String) async throws {
        guard let existingRoom = try await firebaseService.getRoom(id: code) else {
            throw NetworkingError.roomNotFound
        }

        guard existingRoom.status == .waiting || existingRoom.status == .setup else {
            throw RoomError.gameAlreadyStarted
        }

        let playerId = UUID().uuidString
        let player = OnlinePlayer(
            id: playerId,
            deviceId: deviceId,
            name: playerName
        )

        try await firebaseService.addPlayer(player, toRoomId: code)
        self.currentPlayerId = playerId
        startObservingRoom(id: code)
    }

    // MARK: - Room Observation
    private func startObservingRoom(id: String) {
        stopObserving()
        observedRoomId = id
        connectionState = .joining
        roomObserverHandle = firebaseService.observeRoom(id: id) { [weak self] snapshot in
            Task { @MainActor in
                self?.apply(snapshot, forRoomId: id)
            }
        }
        startPresence(forRoomId: id)
    }

    private func startPresence(forRoomId id: String) {
        guard connectivityHandle == nil else { return }
        connectivityHandle = firebaseService.observeConnection { [weak self] isOnline in
            Task { @MainActor in
                self?.handleConnectivity(isOnline, forRoomId: id)
            }
        }
    }

    /// Re-arms presence on every (re)connection while the room is still
    /// there; a server-side `onDisconnect` lasts only for one connection.
    private func handleConnectivity(_ isOnline: Bool, forRoomId id: String) {
        guard isOnline,
              observedRoomId == id,
              !isLeaving,
              connectionState == .joining || connectionState == .live,
              let playerId = currentPlayerId else { return }
        Task {
            try? await firebaseService.armPresence(playerId: playerId, roomId: id)
        }
    }

    /// Stops re-arming presence and cancels the server-side offline write.
    /// Returns the cancelling write so a caller about to remove the player
    /// can wait for it.
    @discardableResult
    private func stopPresence(markOffline: Bool) -> Task<Void, Never>? {
        guard let connectivityHandle else { return nil }
        firebaseService.removeConnectionObserver(connectivityHandle)
        self.connectivityHandle = nil
        guard let playerId = currentPlayerId, let roomId = observedRoomId else { return nil }
        return Task { [firebaseService] in
            try? await firebaseService.disarmPresence(playerId: playerId, roomId: roomId, markOffline: markOffline)
        }
    }

    private func apply(_ snapshot: RoomSnapshot, forRoomId id: String) {
        guard observedRoomId == id, !isLeaving else { return }
        switch snapshot {
        case let .room(room):
            self.room = room
            isConnected = true
            connectionState = .live
        case .missing:
            room = nil
            isConnected = false
            connectionState = .closed
            stopPresence(markOffline: false)
        case .unreadable:
            isConnected = false
            connectionState = .unsupported
        }
    }

    /// Detaches from the room. Safe to call when the room is already gone or
    /// was never received. A player still in a live room is marked offline,
    /// so the host can cover their turn.
    open func stopObserving() {
        stopPresence(markOffline: connectionState == .live)
        if let roomObserverHandle, let observedRoomId {
            firebaseService.removeObserver(handle: roomObserverHandle, forRoomId: observedRoomId)
        }
        roomObserverHandle = nil
        observedRoomId = nil
        room = nil
        isConnected = false
        connectionState = .idle
    }

    // MARK: - Player Actions
    open func joinTeam(teamId: String) async throws {
        guard let player = currentPlayer, let room else { return }
        try await firebaseService.reassignPlayerToTeam(
            playerId: player.id,
            previousTeamId: player.teamId,
            newTeamId: teamId,
            teams: room.teams,
            inRoomId: room.id
        )
    }

    open func leaveTeam() async throws {
        guard let player = currentPlayer, let room else { return }
        try await firebaseService.reassignPlayerToTeam(
            playerId: player.id,
            previousTeamId: player.teamId,
            newTeamId: nil,
            teams: room.teams,
            inRoomId: room.id
        )
    }

    /// Leaves the room. In the lobby the host's departure deletes the room
    /// and a guest's removes their player; once the game has started, or
    /// after the room closed, this only detaches, so the others keep their
    /// game and results. The write happens before detaching, so on failure
    /// the caller is still in the room and can retry.
    open func leaveRoom() async throws {
        let wasHost = isHost
        let roomId = observedRoomId
        let shouldWrite = connectionState == .live && room?.status.isLobby == true

        if let playerId = currentPlayerId, let roomId, shouldWrite {
            isLeaving = true
            defer { isLeaving = false }
            // Cancel the server-side offline write first, or it could
            // recreate this player's node after the removal below.
            await stopPresence(markOffline: false)?.value
            do {
                if wasHost {
                    try await firebaseService.deleteRoom(id: roomId)
                } else {
                    try await firebaseService.removePlayer(playerId: playerId, fromRoomId: roomId)
                }
            } catch {
                startPresence(forRoomId: roomId)
                throw error
            }
        }

        stopObserving()
        currentPlayerId = nil
    }

    // MARK: - Host Actions
    open func createTeam(name: String, colorHex: String) async throws {
        guard isHost, let roomId = room?.id else {
            throw NetworkingError.notAuthorized
        }

        let team = OnlineTeam(name: name, colorHex: colorHex)
        try await firebaseService.addTeam(team, toRoomId: roomId)
    }

    open func removeTeam(teamId: String) async throws {
        guard isHost, let room else {
            throw NetworkingError.notAuthorized
        }

        let memberIds = RoomRules.members(ofTeam: teamId, in: room).map(\.id)
        try await firebaseService.removeTeam(teamId: teamId, unassigning: memberIds, fromRoomId: room.id)
    }

    /// Host-only. Starts the game once `RoomRules` agrees the teams are
    /// playable — the same check the lobby's Start button uses.
    open func startGame() async throws {
        guard isHost, let room else {
            throw NetworkingError.notAuthorized
        }
        guard let started = RoomRules.startGame(room) else {
            throw room.teams.count < RoomRules.minimumTeams ? RoomError.notEnoughTeams : RoomError.notEnoughPlayers
        }

        try await firebaseService.updateRoomStatus(started.status, forRoomId: room.id)
    }

    // MARK: - Word Submission
    /// Adds the player's words and opens their submission gate in one
    /// multi-path write, so a failure leaves neither half behind.
    open func submitWords(_ words: [String]) async throws {
        guard let playerId = currentPlayerId, let roomId = room?.id else { return }

        let onlineWords = words.map { OnlineWord(text: $0, addedByPlayerId: playerId) }
        try await firebaseService.fillWords(onlineWords, markSubmittedPlayerIds: [playerId], toRoomId: roomId)
    }

    /// Host-only automatic word source. Atomically writes a host-generated
    /// pool and opens the submission gate for every player in one write — the
    /// host generated on behalf of the whole room, so no one types words.
    /// All-or-nothing, so a transient failure can be retried without writing
    /// duplicate words.
    open func fillRandomWords(_ texts: [String], hostPlayerId: String) async throws {
        guard let roomId = room?.id else { return }
        let onlineWords = texts.map { OnlineWord(text: $0, addedByPlayerId: hostPlayerId) }
        let playerIds = (room?.players ?? []).map(\.id)
        try await firebaseService.fillWords(onlineWords, markSubmittedPlayerIds: playerIds, toRoomId: roomId)
    }

    // MARK: - Words
    open func getWords() async throws -> [OnlineWord] {
        guard let roomId = room?.id else { return [] }
        return try await firebaseService.getWords(forRoomId: roomId)
    }

    // MARK: - Device ID
    private static func getOrCreateDeviceId() -> String {
        let key = "HatGame.deviceId"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}

public enum RoomError: Error, LocalizedError {
    case gameAlreadyStarted
    case roomFull
    case teamFull
    case notEnoughPlayers
    case notEnoughTeams

    public var errorDescription: String? {
        switch self {
        case .gameAlreadyStarted:
            return "Game has already started"
        case .roomFull:
            return "Room is full"
        case .teamFull:
            return "Team is full"
        case .notEnoughPlayers:
            return "Not enough players to start"
        case .notEnoughTeams:
            return "Need at least 2 teams to start"
        }
    }
}
