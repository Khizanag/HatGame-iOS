//
//  RoomManager.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import FirebaseDatabase
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.khizanag.hat-game", category: "RoomManager")

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
    /// The latest presence arming, so stopping presence can settle it first.
    @ObservationIgnored private var presenceTask: Task<Void, Never>?
    /// A timed-out write may still land, so a retry must reuse the identity
    /// of the attempt before it rather than mint a second room, player, or
    /// team. Kept for the life of this manager.
    @ObservationIgnored private var pendingCreation: PendingCreation?
    @ObservationIgnored private var pendingPlayers: [String: OnlinePlayer] = [:]
    @ObservationIgnored private var pendingTeams: [String: OnlineTeam] = [:]
    /// Stable per-device UUID kept in UserDefaults so reconnects map back
    /// to the same player record.
    internal var deviceId: String

    public var isHost: Bool {
        room?.hostId == currentPlayerId
    }

    /// The room's shared clock: the database server's time online, the
    /// host's on nearby. Countdowns and turn checks read this, never the
    /// device's own clock, so every device agrees on when a turn ends.
    open var now: Date {
        firebaseService.serverNow()
    }

    /// May take host-only game actions: the host, or the player standing
    /// in for a host who has dropped out (see `OnlineGameRules.actingHostId`).
    public var canActAsHost: Bool {
        guard let room, let currentPlayerId else { return false }
        return OnlineGameRules.canActAsHost(currentPlayerId, hostId: room.hostId, players: room.players)
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
        presenceTask?.cancel()
        if let roomObserverHandle, let observedRoomId {
            firebaseService.removeObserver(handle: roomObserverHandle, forRoomId: observedRoomId)
        }
        if let connectivityHandle {
            firebaseService.removeConnectionObserver(connectivityHandle)
        }
    }

    // MARK: - Room Creation
    /// Draws codes until one is free. With 32^6 codes a collision is rare, so
    /// a handful of attempts is plenty. Retrying after a timeout re-sends the
    /// same room, which counts as created if the first attempt landed.
    open func createRoom(hostName: String, settings: GameSettings) async throws -> String {
        var candidate = pendingCreation.flatMap { $0.matches(hostName, settings) ? $0.room : nil }
            ?? Self.newRoom(hostName: hostName, settings: settings, deviceId: deviceId)

        for _ in 0..<5 {
            pendingCreation = PendingCreation(hostName: hostName, settings: settings, room: candidate)
            let isCreated: Bool
            do {
                isCreated = try await firebaseService.createRoom(candidate)
            } catch {
                if !writeMayStillLand(error) { pendingCreation = nil }
                throw error
            }
            if isCreated {
                pendingCreation = nil
                self.currentPlayerId = candidate.hostId
                startObservingRoom(id: candidate.id)
                return candidate.id
            }
            candidate = candidate.withCode(RoomCode.random())
        }
        pendingCreation = nil
        throw NetworkingError.failedToGenerateRoomCode
    }

    /// The host starts offline: presence marks them connected once the
    /// server confirms this client's connection.
    private static func newRoom(hostName: String, settings: GameSettings, deviceId: String) -> GameRoom {
        let host = OnlinePlayer(deviceId: deviceId, name: hostName, isReady: true, isConnected: false)
        return GameRoom(id: RoomCode.random(), hostId: host.id, status: .waiting, settings: settings, players: [host])
    }

    // MARK: - Room Joining
    open func joinRoom(code: String, playerName: String) async throws {
        guard let existingRoom = try await firebaseService.getRoom(id: code) else {
            throw NetworkingError.roomNotFound
        }
        guard existingRoom.isSupported else {
            throw NetworkingError.unsupportedVersion
        }

        // This device already has a seat — it dropped out or restarted.
        // Take it back, team and words intact; presence marks it connected.
        if let returning = RoomRules.returningPlayer(deviceId: deviceId, in: existingRoom) {
            pendingPlayers[code] = returning
            self.currentPlayerId = returning.id
            startObservingRoom(id: code)
            return
        }

        guard existingRoom.status == .waiting || existingRoom.status == .setup else {
            throw RoomError.gameAlreadyStarted
        }

        // One player identity per room code: a retry after a timed-out write
        // rewrites the same node instead of adding a second player.
        let pending = pendingPlayers[code]
        let player = OnlinePlayer(
            id: pending?.id ?? UUID().uuidString,
            deviceId: deviceId,
            name: playerName,
            isConnected: false,
            joinedAt: pending?.joinedAt ?? Date()
        )
        pendingPlayers[code] = player

        do {
            try await firebaseService.addPlayer(player, toRoomId: code)
        } catch {
            if !writeMayStillLand(error) { pendingPlayers[code] = nil }
            throw error
        }
        self.currentPlayerId = player.id
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
        presenceTask?.cancel()
        presenceTask = Task { [firebaseService] in
            try? await firebaseService.armPresence(playerId: playerId, roomId: id)
        }
    }

    /// Stops re-arming presence and cancels the server-side offline write.
    /// An arming still in flight is cancelled and awaited first, so its
    /// `onDisconnect` cannot be registered after the disarm. Returns the
    /// disarm so a caller about to remove the player can wait for it.
    @discardableResult
    private func stopPresence(markOffline: Bool) -> Task<Void, Never>? {
        let arming = presenceTask
        presenceTask = nil
        arming?.cancel()
        guard let connectivityHandle else { return nil }
        firebaseService.removeConnectionObserver(connectivityHandle)
        self.connectivityHandle = nil
        guard let playerId = currentPlayerId, let roomId = observedRoomId else { return nil }
        return Task { [firebaseService] in
            await arming?.value
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
            // The room is gone for good; stop listening at its path.
            if let roomObserverHandle {
                firebaseService.removeObserver(handle: roomObserverHandle, forRoomId: id)
                self.roomObserverHandle = nil
            }
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
    /// game and results.
    ///
    /// A write the server refused leaves the caller in the room, presence
    /// re-armed, to retry. A write that timed out is still queued and will
    /// land when the connection returns, so the caller detaches as if it had
    /// succeeded — re-arming presence there would let the queued offline
    /// write recreate a player who is being removed.
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
            } catch where writeMayStillLand(error) {
                logger.info("Leave of \(roomId, privacy: .public) is pending; detaching")
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

        // Re-submitting the same team after a timeout reuses its id.
        let key = "\(roomId)/\(name)/\(colorHex)"
        let team = pendingTeams[key] ?? OnlineTeam(name: name, colorHex: colorHex)
        pendingTeams[key] = team
        do {
            try await firebaseService.addTeam(team, toRoomId: roomId)
            pendingTeams[key] = nil
        } catch {
            if !writeMayStillLand(error) { pendingTeams[key] = nil }
            throw error
        }
    }

    /// Host-only, lobby-only. Removes a player whose device dropped off (app
    /// closed, connection lost) so the room stops waiting on them. Players
    /// who leave on purpose remove themselves.
    open func removeAwayPlayer(_ playerId: String) async throws {
        guard isHost, let room else {
            throw NetworkingError.notAuthorized
        }
        guard room.status.isLobby,
              playerId != currentPlayerId,
              let player = room.players.first(where: { $0.id == playerId }),
              !player.isConnected else { return }
        try await firebaseService.removePlayer(playerId: playerId, fromRoomId: room.id)
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
    /// multi-path write, so a failure leaves neither half behind. Word ids
    /// are derived from the player, so a resend overwrites rather than adds.
    open func submitWords(_ words: [String]) async throws {
        guard let playerId = currentPlayerId, let roomId = room?.id else { return }

        let onlineWords = OnlineWord.submission(words, by: playerId)
        try await firebaseService.fillWords(onlineWords, markSubmittedPlayerIds: [playerId], toRoomId: roomId)
    }

    /// Automatic word source, run by whoever can act as host. Atomically
    /// writes the generated pool and opens the submission gate for every
    /// player in one write — the pool is drawn for the whole room, so no one
    /// types words. Ids come from `OnlineWord.automatic`, so a retry or a
    /// second generator rewrites the same entries instead of adding more.
    open func fillRandomWords(_ words: [OnlineWord]) async throws {
        guard let roomId = room?.id else { return }
        let playerIds = (room?.players ?? []).map(\.id)
        try await firebaseService.fillWords(words, markSubmittedPlayerIds: playerIds, toRoomId: roomId)
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

/// A room whose create may still land; reused only for an identical request.
private struct PendingCreation {
    let hostName: String
    let settings: GameSettings
    let room: GameRoom

    func matches(_ hostName: String, _ settings: GameSettings) -> Bool {
        self.hostName == hostName && self.settings == settings
    }
}

// MARK: - Code collisions
private extension GameRoom {
    func withCode(_ code: String) -> GameRoom {
        GameRoom(
            id: code,
            hostId: hostId,
            schemaVersion: schemaVersion,
            status: status,
            settings: settings,
            teams: teams,
            players: players,
            gameState: gameState,
            createdAt: createdAt
        )
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
