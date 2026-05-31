//
//  LocalGameSyncManager.swift
//  Networking
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import Foundation
import Observation

/// `GameSyncManager` whose transport is `LocalMultipeerService` instead of
/// Firebase. Hosts mutate the canonical `OnlineGameState` carried inside
/// `RoomManager.room.gameState` and broadcast a fresh snapshot through the
/// owning `LocalRoomManager`. Guests post the matching `ClientAction` and
/// wait for the snapshot.
@MainActor
@Observable
public final class LocalGameSyncManager: GameSyncManager {
    /// Weak ref back to the LocalRoomManager — that's where the MC
    /// transport lives, plus the canonical room snapshot for hosts to
    /// mutate. Required so we can route actions and broadcasts.
    public weak var roomManager: LocalRoomManager?

    public init(roomManager: LocalRoomManager) {
        self.roomManager = roomManager
        super.init()
    }

    private var isHost: Bool {
        roomManager?.isHostInternal ?? false
    }

    // MARK: - Game initialization
    public override func initializeGame(
        for roomId: String,
        teams: [OnlineTeam],
        players: [OnlinePlayer],
        words: [OnlineWord],
        settings: GameSettings
    ) async throws -> OnlineGameState {
        guard let roomManager, isHost else {
            return OnlineGameState(roundDuration: settings.roundDuration, isSkippingEnabled: settings.isSkippingEnabled)
        }

        let shuffledWordIds = words.map(\.id).shuffled()
        var initialScores: [String: [OnlineGameRound: Int]] = [:]
        var initialExplainerIndices: [String: Int] = [:]
        for team in teams {
            initialScores[team.id] = [.first: 0, .second: 0, .third: 0]
            initialExplainerIndices[team.id] = 0
        }
        let firstTeam = teams.first
        let firstExplainerId = firstTeam.flatMap { team in
            playersInTeam(team, allPlayers: players).first?.id
        }
        let state = OnlineGameState(
            currentRound: .first,
            currentTeamIndex: 0,
            teamExplainerIndices: initialExplainerIndices,
            currentWordId: shuffledWordIds.first,
            remainingWordIds: shuffledWordIds,
            allWordIds: shuffledWordIds,
            scores: initialScores,
            phase: .teamPrep,
            activePlayerId: firstExplainerId,
            roundDuration: settings.roundDuration,
            isSkippingEnabled: settings.isSkippingEnabled
        )

        try await roomManager.updateGameState(state)
        return state
    }

    // MARK: - Turn lifecycle
    public override func startTurn(roomId: String, gameState: OnlineGameState) async throws {
        var next = gameState
        next.phase = .playing
        next.timerStartedAt = Date()
        try await applyOrForward(state: next, action: .startTurn)
    }

    public override func markWordGuessed(
        roomId: String,
        gameState: OnlineGameState,
        teams: [OnlineTeam]
    ) async throws {
        guard let wordId = gameState.currentWordId else { return }
        var next = gameState
        if let teamId = teams[safe: gameState.currentTeamIndex]?.id {
            var perRound = next.scores[teamId] ?? [:]
            perRound[gameState.currentRound, default: 0] += 1
            next.scores[teamId] = perRound
        }
        next.remainingWordIds.removeAll { $0 == wordId }
        next.currentWordId = next.remainingWordIds.first
        try await applyOrForward(state: next, action: .markWordGuessed)
    }

    public override func skipWord(roomId: String, gameState: OnlineGameState) async throws {
        guard gameState.isSkippingEnabled,
              let currentId = gameState.currentWordId,
              gameState.remainingWordIds.count > 1 else { return }
        var next = gameState
        next.remainingWordIds.removeAll { $0 == currentId }
        next.remainingWordIds.append(currentId)
        next.currentWordId = next.remainingWordIds.first
        try await applyOrForward(state: next, action: .skipWord)
    }

    public override func endTurn(roomId: String, gameState: OnlineGameState) async throws {
        var next = gameState
        next.phase = .turnResults
        next.timerStartedAt = nil
        try await applyOrForward(state: next, action: .endTurn)
    }

    // MARK: - Phase advancement
    public override func advanceAfterTurnResults(
        roomId: String,
        gameState: OnlineGameState,
        teams: [OnlineTeam],
        players: [OnlinePlayer]
    ) async throws {
        guard !teams.isEmpty else { return }
        var next = gameState

        if next.remainingWordIds.isEmpty {
            next.phase = .roundResults
            try await applyOrForward(state: next, action: .advanceAfterTurnResults)
            return
        }

        if let previousTeam = teams[safe: gameState.currentTeamIndex] {
            let previousIndex = next.teamExplainerIndices[previousTeam.id] ?? 0
            let teamSize = max(playersInTeam(previousTeam, allPlayers: players).count, 1)
            next.teamExplainerIndices[previousTeam.id] = (previousIndex + 1) % teamSize
        }
        next.currentTeamIndex = (gameState.currentTeamIndex + 1) % teams.count
        let nextTeam = teams[next.currentTeamIndex]
        let nextTeamPlayers = playersInTeam(nextTeam, allPlayers: players)
        let nextExplainerIndex = next.teamExplainerIndices[nextTeam.id] ?? 0
        next.activePlayerId = nextTeamPlayers[safe: nextExplainerIndex]?.id
        next.phase = .teamPrep
        next.currentWordId = next.remainingWordIds.first
        try await applyOrForward(state: next, action: .advanceAfterTurnResults)
    }

    public override func advanceAfterRoundResults(
        roomId: String,
        gameState: OnlineGameState,
        teams: [OnlineTeam],
        players: [OnlinePlayer]
    ) async throws {
        var next = gameState
        guard let upcoming = gameState.currentRound.next else {
            next.phase = .finished
            try await applyOrForward(state: next, action: .advanceAfterRoundResults)
            // Also flip room status to finished.
            if let manager = roomManager, manager.isHostInternal {
                try await manager.updateRoomStatus(.finished)
            }
            return
        }
        next.currentRound = upcoming
        next.remainingWordIds = gameState.allWordIds.shuffled()
        next.currentWordId = next.remainingWordIds.first
        let team = teams[safe: next.currentTeamIndex]
        let teamPlayers = team.map { playersInTeam($0, allPlayers: players) } ?? []
        let explainerIndex = team.map { next.teamExplainerIndices[$0.id] ?? 0 } ?? 0
        next.activePlayerId = teamPlayers[safe: explainerIndex]?.id
        next.phase = .teamPrep
        next.timerStartedAt = nil
        try await applyOrForward(state: next, action: .advanceAfterRoundResults)
    }

    // MARK: - Routing
    /// Host: mutate canonical state via the roomManager (which broadcasts).
    /// Guest: send the matching ClientAction and let the host snapshot
    /// rebound back.
    private func applyOrForward(state: OnlineGameState, action: ClientAction) async throws {
        if let manager = roomManager, manager.isHostInternal {
            try await manager.updateGameState(state)
        } else if let manager = roomManager {
            manager.forwardClientAction(action)
        }
    }

    private func playersInTeam(_ team: OnlineTeam, allPlayers: [OnlinePlayer]) -> [OnlinePlayer] {
        if !team.playerIds.isEmpty {
            let lookup = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0) })
            return team.playerIds.compactMap { lookup[$0] }
        }
        return allPlayers.filter { $0.teamId == team.id }
    }
}

// MARK: - Safe subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
