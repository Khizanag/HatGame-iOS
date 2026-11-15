//
//  LocalRoomManager.swift
//  Networking
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import Foundation
@preconcurrency import MultipeerConnectivity
import Observation
import OSLog

private let logger = Logger(subsystem: "com.khizanag.hat-game", category: "LocalRoomManager")

/// `RoomManager` whose transport is Apple's `MultipeerConnectivity` instead
/// of Firebase. Authority model is identical to the Firebase path: only the
/// host mutates canonical state; guests post `ClientAction`s and wait for
/// the host's broadcast `roomSnapshot` to apply locally. Every mutation runs
/// through `RoomRules` / `GameRules`, so a guest can do exactly what the
/// same player could do online and nothing more.
///
/// One instance is created per local-play session. Hosts create it via
/// `createRoom(...)`; guests create it via `connectToHost(_:playerName:)`.
@MainActor
@Observable
public final class LocalRoomManager: RoomManager {
    public enum LocalError: Error, LocalizedError {
        case notImplementedForLocal
        case hostOnly
        case notConnected

        public var errorDescription: String? {
            switch self {
            case .notImplementedForLocal: "This action isn't supported in nearby play."
            case .hostOnly: "Only the host can do this."
            case .notConnected: "Not connected to any host yet."
            }
        }
    }

    /// Bag of words held by the host. Broadcast via `wordsSnapshot`.
    public private(set) var words: [OnlineWord] = []
    /// Browser-driven list of nearby rooms — populated when the local
    /// manager is in guest browsing mode (before `connectToHost` succeeds).
    public private(set) var discoveredHosts: [LocalMultipeerService.DiscoveredHost] = []

    private let service: LocalMultipeerService
    /// Map MC peer → playerId so we can route ClientActions back to the
    /// correct OnlinePlayer record. Host-side only; an entry exists only for
    /// a peer whose hello was accepted.
    private var peerToPlayerId: [MCPeerID: String] = [:]
    /// Player record for the local user. Set in createRoom / connectToHost.
    private var localPlayer: OnlinePlayer?
    /// True for the device that called createRoom.
    private var isLocalHost: Bool = false

    public var isHostInternal: Bool { isLocalHost }

    public init(displayName: String) {
        self.service = LocalMultipeerService(displayName: displayName)
        super.init()
        wireServiceCallbacks()
    }

    private func wireServiceCallbacks() {
        service.onPeerStateChange = { [weak self] peer, state in
            self?.handlePeerStateChange(peer: peer, state: state)
        }
        service.onMessage = { [weak self] message, peer in
            self?.handleMessage(message, fromPeer: peer)
        }
        service.onHostFound = { [weak self] host in
            guard let self else { return }
            if !discoveredHosts.contains(where: { $0.id == host.id }) {
                discoveredHosts.append(host)
            }
        }
        service.onHostLost = { [weak self] peer in
            self?.discoveredHosts.removeAll { $0.id == peer }
        }
    }

    // MARK: - Guest browsing
    public func startBrowsingForHosts() {
        discoveredHosts.removeAll()
        service.startBrowsing()
    }

    /// Stops discovery only; a connection to a host already made survives.
    public func stopBrowsingForHosts() {
        service.stopBrowsing()
    }

    /// Joins `host` over the session the browser found it with, returning
    /// once the peers are connected. The hello and the host's first snapshot
    /// follow from the `.connected` event.
    public func connectToHost(_ host: LocalMultipeerService.DiscoveredHost, playerName: String) async throws {
        let player = OnlinePlayer(deviceId: deviceId, name: playerName)
        self.localPlayer = player
        self.currentPlayerId = player.id
        self.isLocalHost = false
        do {
            try await service.connect(to: host.id)
        } catch {
            self.localPlayer = nil
            self.currentPlayerId = nil
            throw error
        }
        service.stopBrowsing()
    }

    // MARK: - RoomManager overrides
    public override func createRoom(hostName: String, settings: GameSettings) async throws -> String {
        let host = OnlinePlayer(
            deviceId: deviceId,
            name: hostName,
            isReady: true
        )
        self.localPlayer = host
        self.currentPlayerId = host.id
        self.isLocalHost = true
        self.words = []

        let room = GameRoom(
            id: "local-\(UUID().uuidString.prefix(8))",
            hostId: host.id,
            settings: settings,
            players: [host]
        )
        self.room = room
        self.isConnected = true

        service.startHosting(discoveryInfo: ["host": hostName])
        return room.id
    }

    public override func joinRoom(code: String, playerName: String) async throws {
        // Local play uses browse-and-tap, not codes. The OnlineMenu's Join
        // CTA routes to the LocalRoomBrowser view directly.
        throw LocalError.notImplementedForLocal
    }

    public override func joinTeam(teamId: String) async throws {
        try perform(.joinTeam(teamId: teamId))
    }

    public override func leaveTeam() async throws {
        try perform(.leaveTeam)
    }

    public override func createTeam(name: String, colorHex: String) async throws {
        try perform(.createTeam(name: name, colorHex: colorHex))
    }

    public override func removeTeam(teamId: String) async throws {
        try perform(.removeTeam(teamId: teamId))
    }

    public override func startGame() async throws {
        try perform(.startGame)
    }

    public override func submitWords(_ submitted: [String]) async throws {
        try perform(.submitWords(submitted))
    }

    public override func markWordsSubmitted() async throws {
        // submitWords opens the gate in the same step on the host.
    }

    public override func updateRoomStatus(_ status: RoomStatus) async throws {
        guard isLocalHost else { throw LocalError.hostOnly }
        guard var room else { return }
        room.status = status
        self.room = room
        broadcastSnapshot()
    }

    public override func fillRandomWords(_ texts: [String], hostPlayerId: String) async throws {
        guard isLocalHost else { throw LocalError.hostOnly }
        guard let room, let next = RoomRules.markAllWordsSubmitted(in: room) else { return }
        words.append(contentsOf: texts.map { OnlineWord(text: $0, addedByPlayerId: hostPlayerId) })
        self.room = next
        broadcastWords()
        broadcastSnapshot()
    }

    public override func getWords() async throws -> [OnlineWord] {
        words
    }

    public override func leaveRoom() async throws {
        service.endSession()
        room = nil
        words = []
        currentPlayerId = nil
        localPlayer = nil
        isConnected = false
        peerToPlayerId.removeAll()
    }

    // MARK: - Gameplay
    /// Called by `LocalGameSyncManager` on guest devices to forward a
    /// gameplay action to the host.
    func forwardGameAction(_ action: GameAction) {
        guard !isLocalHost else { return }
        service.send(.clientAction(.game(action)))
    }

    /// Host-only. Seeds the first game state from the shuffled word pool.
    func initializeGame(wordIds: [String]) -> Bool {
        guard isLocalHost,
              var room,
              room.gameState == nil,
              let state = GameRules.initialState(
                  teams: room.teams,
                  players: room.players,
                  wordIds: wordIds,
                  settings: room.settings
              ) else { return false }
        room.gameState = state
        self.room = room
        broadcastSnapshot()
        return true
    }

    /// Host-only. Applies a gameplay action through `GameRules` and
    /// broadcasts the result. Serves the host's own taps and every guest's.
    func applyGameAction(_ action: GameAction, by playerId: String) -> Bool {
        guard isLocalHost,
              var room,
              let state = room.gameState,
              let next = GameRules.apply(action, by: playerId, to: state, context: GameContext(room: room))
        else { return false }
        room.gameState = next
        if next.phase == .finished {
            room.status = .finished
        }
        self.room = room
        broadcastSnapshot()
        return true
    }
}

// MARK: - Lobby actions
private extension LocalRoomManager {
    /// Host: apply directly. Guest: forward to the host, refusing host-only
    /// actions up front so the UI gets an error instead of silence.
    func perform(_ action: RoomAction) throws {
        if isLocalHost {
            guard let playerId = currentPlayerId else { return }
            applyRoomAction(action, by: playerId)
            return
        }
        switch action {
        case .createTeam, .removeTeam, .startGame:
            throw LocalError.hostOnly
        case .joinTeam, .leaveTeam, .submitWords:
            service.send(.clientAction(.room(action)))
        }
    }

    @discardableResult
    func applyRoomAction(_ action: RoomAction, by playerId: String) -> Bool {
        guard isLocalHost, let room, RoomRules.canPerform(action, by: playerId, in: room) else { return false }
        var addedWords: [OnlineWord] = []
        let next: GameRoom?
        switch action {
        case let .joinTeam(teamId):
            next = RoomRules.joinTeam(teamId, playerId: playerId, in: room)
        case .leaveTeam:
            next = RoomRules.leaveTeam(playerId: playerId, in: room)
        case let .createTeam(name, colorHex):
            next = RoomRules.createTeam(OnlineTeam(name: name, colorHex: colorHex), in: room)
        case let .removeTeam(teamId):
            next = RoomRules.removeTeam(teamId, in: room)
        case .startGame:
            next = RoomRules.startGame(room)
        case let .submitWords(texts):
            next = RoomRules.submitWords(playerId: playerId, in: room)
            addedWords = texts.map { OnlineWord(text: $0, addedByPlayerId: playerId) }
        }
        guard let next else { return false }
        self.room = next
        if !addedWords.isEmpty {
            words.append(contentsOf: addedWords)
            broadcastWords()
        }
        broadcastSnapshot()
        return true
    }
}

// MARK: - Transport events
private extension LocalRoomManager {
    func broadcastSnapshot() {
        guard isLocalHost, let room else { return }
        service.send(.roomSnapshot(room))
    }

    func broadcastWords() {
        guard isLocalHost else { return }
        service.send(.wordsSnapshot(words))
    }

    func handlePeerStateChange(peer: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            if isLocalHost {
                // Wait for helloFromGuest before adding to players list.
            } else {
                // Guest just connected to host. Identify ourselves.
                if let player = localPlayer {
                    service.send(.helloFromGuest(player), to: [peer])
                }
                isConnected = true
            }
        case .notConnected:
            if isLocalHost {
                guard let playerId = peerToPlayerId.removeValue(forKey: peer),
                      let room,
                      let next = RoomRules.playerLeft(playerId, from: room) else { return }
                self.room = next
                broadcastSnapshot()
            } else if peer != service.localPeerID {
                // Host went away.
                isConnected = false
            }
        default:
            break
        }
    }

    func handleMessage(_ message: LocalMessage, fromPeer peer: MCPeerID) {
        switch message {
        case let .roomSnapshot(snapshot):
            guard !isLocalHost else { return }
            self.room = snapshot
            self.isConnected = true
        case let .wordsSnapshot(snapshot):
            guard !isLocalHost else { return }
            self.words = snapshot
        case let .helloFromGuest(player):
            admitGuest(player, fromPeer: peer)
        case let .clientAction(action):
            guard isLocalHost, let playerId = peerToPlayerId[peer] else { return }
            switch action {
            case let .room(roomAction):
                applyRoomAction(roomAction, by: playerId)
            case let .game(gameAction):
                _ = applyGameAction(gameAction, by: playerId)
            }
        }
    }

    /// Host-only. A peer gets an identity only once `RoomRules` admits the
    /// player it announced: the lobby must be open and the id unused, so a
    /// guest cannot claim the host's (or anyone's) id, and one peer cannot
    /// register twice.
    func admitGuest(_ player: OnlinePlayer, fromPeer peer: MCPeerID) {
        guard isLocalHost,
              peerToPlayerId[peer] == nil,
              let room,
              let next = RoomRules.addPlayer(player, to: room) else {
            logger.info("Rejected hello from \(peer.displayName, privacy: .public)")
            return
        }
        peerToPlayerId[peer] = player.id
        self.room = next
        broadcastSnapshot()
        broadcastWords()
    }
}
