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
/// the host's broadcast `roomSnapshot` to apply locally.
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
    /// correct OnlinePlayer record. Host-side only.
    private var peerToPlayerId: [MCPeerID: String] = [:]
    /// Player record for the local user. Set in createRoom / connectToHost.
    private var localPlayer: OnlinePlayer?
    /// True for the device that called createRoom.
    private var isLocalHost: Bool = false

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

    public func stopBrowsingForHosts() {
        service.stop()
    }

    public func connectToHost(_ host: LocalMultipeerService.DiscoveredHost, playerName: String) async throws {
        let player = OnlinePlayer(deviceId: deviceId, name: playerName)
        self.localPlayer = player
        self.currentPlayerId = player.id
        self.isLocalHost = false
        service.startBrowsing() // ensure session exists (if not already)
        service.invite(host: host.id)
        // Snapshot will arrive after the host receives helloFromGuest.
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

    public override func updatePlayerReady(_ isReady: Bool) async throws {
        if isLocalHost {
            updateLocalPlayer { $0.isReady = isReady }
        } else {
            // For now ready is implicit; no remote message needed.
        }
    }

    public override func joinTeam(teamId: String) async throws {
        if isLocalHost {
            applyJoinTeam(playerId: currentPlayerId ?? "", teamId: teamId)
        } else {
            service.send(.clientAction(.joinTeam(teamId: teamId)))
        }
    }

    public override func leaveTeam() async throws {
        if isLocalHost {
            applyLeaveTeam(playerId: currentPlayerId ?? "")
        } else {
            service.send(.clientAction(.leaveTeam))
        }
    }

    public override func markWordsSubmitted() async throws {
        if isLocalHost {
            updateLocalPlayer { $0.hasSubmittedWords = true }
        }
        // Guests: submitWords already toggles this on the host side.
    }

    public override func leaveRoom() async throws {
        service.stop()
        room = nil
        words = []
        currentPlayerId = nil
        localPlayer = nil
        isConnected = false
        peerToPlayerId.removeAll()
    }

    public override func createTeam(name: String, colorHex: String) async throws {
        if isLocalHost {
            applyCreateTeam(name: name, colorHex: colorHex)
        } else {
            service.send(.clientAction(.createTeam(name: name, colorHex: colorHex)))
        }
    }

    public override func removeTeam(teamId: String) async throws {
        if isLocalHost {
            applyRemoveTeam(teamId: teamId)
        } else {
            service.send(.clientAction(.removeTeam(teamId: teamId)))
        }
    }

    public override func updateSettings(_ settings: GameSettings) async throws {
        guard isLocalHost else { throw LocalError.hostOnly }
        guard var room else { return }
        room.settings = settings
        self.room = room
        broadcastSnapshot()
    }

    public override func updateRoomStatus(_ status: RoomStatus) async throws {
        guard isLocalHost else { throw LocalError.hostOnly }
        applyRoomStatus(status)
    }

    public override func startGame() async throws {
        if isLocalHost {
            applyRoomStatus(.playing)
        } else {
            service.send(.clientAction(.startGame))
        }
    }

    public override func submitWords(_ submitted: [String]) async throws {
        if isLocalHost {
            applySubmitWords(playerId: currentPlayerId ?? "", words: submitted)
        } else {
            service.send(.clientAction(.submitWords(submitted)))
        }
    }

    public override func fillRandomWords(_ texts: [String], hostPlayerId: String) async throws {
        guard isLocalHost else { throw LocalError.hostOnly }
        let onlineWords = texts.map { OnlineWord(text: $0, addedByPlayerId: hostPlayerId) }
        self.words.append(contentsOf: onlineWords)
        guard var room else { return }
        for index in room.players.indices {
            room.players[index].hasSubmittedWords = true
        }
        self.room = room
        broadcastSnapshot()
        broadcastWords()
    }

    public override func updateGameState(_ state: OnlineGameState) async throws {
        guard isLocalHost else { throw LocalError.hostOnly }
        guard var room else { return }
        room.gameState = state
        self.room = room
        broadcastSnapshot()
    }

    public override func getWords() async throws -> [OnlineWord] {
        words
    }

    // MARK: - Host-side mutators
    public var isHostInternal: Bool { isLocalHost }

    func broadcastSnapshot() {
        guard isLocalHost, let room else { return }
        service.send(.roomSnapshot(room))
    }

    func broadcastWords() {
        guard isLocalHost else { return }
        service.send(.wordsSnapshot(words))
    }

    /// Called by `LocalGameSyncManager` on guest devices to forward a typed
    /// game-flow action to the host. Hosts mutate state directly via
    /// `updateGameState` instead of using this path.
    func forwardClientAction(_ action: ClientAction) {
        guard !isLocalHost else { return }
        service.send(.clientAction(action))
    }

    private func handlePeerStateChange(peer: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            if isLocalHost {
                // Wait for helloFromGuest before adding to players list.
                // Once we have the guest's OnlinePlayer record, the
                // handleMessage path appends it and broadcasts.
            } else {
                // Guest just connected to host. Identify ourselves.
                if let player = localPlayer {
                    service.send(.helloFromGuest(player), to: [peer])
                }
                isConnected = true
            }
        case .notConnected:
            if isLocalHost {
                if let playerId = peerToPlayerId.removeValue(forKey: peer) {
                    applyPlayerLeft(playerId: playerId)
                }
            } else if peer != service.localPeerID {
                // Host went away.
                isConnected = false
            }
        default:
            break
        }
    }

    private func handleMessage(_ message: LocalMessage, fromPeer peer: MCPeerID) {
        switch message {
        case .roomSnapshot(let snapshot):
            // Guest path: trust the host.
            guard !isLocalHost else { return }
            self.room = snapshot
            self.isConnected = true
        case .wordsSnapshot(let snapshot):
            guard !isLocalHost else { return }
            self.words = snapshot
        case .helloFromGuest(let player):
            // Host path: register the new guest and broadcast — but only while
            // still in the lobby. Adding a player mid-game would reopen the
            // word-submission gate and yank everyone back to setup, so late
            // joiners are ignored (mirrors the Firebase joinRoom status guard).
            guard isLocalHost else { return }
            guard let status = room?.status, status == .waiting || status == .setup else { return }
            peerToPlayerId[peer] = player.id
            applyAddPlayer(player)
        case .clientAction(let action):
            guard isLocalHost, let playerId = peerToPlayerId[peer] else { return }
            applyAction(action, playerId: playerId)
        }
    }

    private func applyAction(_ action: ClientAction, playerId: String) {
        switch action {
        case .joinTeam(let teamId): applyJoinTeam(playerId: playerId, teamId: teamId)
        case .leaveTeam: applyLeaveTeam(playerId: playerId)
        case .createTeam(let name, let colorHex): applyCreateTeam(name: name, colorHex: colorHex)
        case .removeTeam(let teamId): applyRemoveTeam(teamId: teamId)
        case .startGame: applyRoomStatus(.playing)
        case .submitWords(let words): applySubmitWords(playerId: playerId, words: words)
        case .startTurn, .markWordGuessed, .skipWord, .endTurn,
             .advanceAfterTurnResults, .advanceAfterRoundResults:
            // These are routed through LocalGameSyncManager.applyOnHost.
            break
        }
    }

    // MARK: - State mutations (host-side)
    private func updateLocalPlayer(_ mutate: (inout OnlinePlayer) -> Void) {
        guard var room, let playerId = currentPlayerId else { return }
        guard let index = room.players.firstIndex(where: { $0.id == playerId }) else { return }
        var player = room.players[index]
        mutate(&player)
        room.players[index] = player
        self.room = room
        broadcastSnapshot()
    }

    private func applyAddPlayer(_ player: OnlinePlayer) {
        guard var room else { return }
        guard !room.players.contains(where: { $0.id == player.id }) else { return }
        room.players.append(player)
        self.room = room
        broadcastSnapshot()
        broadcastWords()
    }

    private func applyPlayerLeft(playerId: String) {
        guard var room else { return }
        room.players.removeAll { $0.id == playerId }
        // Also yank from any team's playerIds.
        for index in room.teams.indices {
            room.teams[index].playerIds.removeAll { $0 == playerId }
        }
        self.room = room
        broadcastSnapshot()
    }

    private func applyJoinTeam(playerId: String, teamId: String) {
        guard var room else { return }
        // Strip from previous team, attach to new.
        if let previousTeamId = room.players.first(where: { $0.id == playerId })?.teamId,
           previousTeamId != teamId,
           let previousIndex = room.teams.firstIndex(where: { $0.id == previousTeamId }) {
            room.teams[previousIndex].playerIds.removeAll { $0 == playerId }
        }
        if let teamIndex = room.teams.firstIndex(where: { $0.id == teamId }),
           !room.teams[teamIndex].playerIds.contains(playerId) {
            room.teams[teamIndex].playerIds.append(playerId)
        }
        if let playerIndex = room.players.firstIndex(where: { $0.id == playerId }) {
            room.players[playerIndex].teamId = teamId
        }
        self.room = room
        broadcastSnapshot()
    }

    private func applyLeaveTeam(playerId: String) {
        guard var room else { return }
        if let previousTeamId = room.players.first(where: { $0.id == playerId })?.teamId,
           let previousIndex = room.teams.firstIndex(where: { $0.id == previousTeamId }) {
            room.teams[previousIndex].playerIds.removeAll { $0 == playerId }
        }
        if let playerIndex = room.players.firstIndex(where: { $0.id == playerId }) {
            room.players[playerIndex].teamId = nil
        }
        self.room = room
        broadcastSnapshot()
    }

    private func applyCreateTeam(name: String, colorHex: String) {
        guard var room else { return }
        let team = OnlineTeam(name: name, colorHex: colorHex)
        room.teams.append(team)
        self.room = room
        broadcastSnapshot()
    }

    private func applyRemoveTeam(teamId: String) {
        guard var room else { return }
        room.teams.removeAll { $0.id == teamId }
        // Unassign any players in that team.
        for index in room.players.indices where room.players[index].teamId == teamId {
            room.players[index].teamId = nil
        }
        self.room = room
        broadcastSnapshot()
    }

    private func applyRoomStatus(_ status: RoomStatus) {
        guard var room else { return }
        room.status = status
        self.room = room
        broadcastSnapshot()
    }

    private func applySubmitWords(playerId: String, words: [String]) {
        let onlineWords = words.map { OnlineWord(text: $0, addedByPlayerId: playerId) }
        self.words.append(contentsOf: onlineWords)
        guard var room else { return }
        if let index = room.players.firstIndex(where: { $0.id == playerId }) {
            room.players[index].hasSubmittedWords = true
        }
        self.room = room
        broadcastSnapshot()
        broadcastWords()
    }
}
