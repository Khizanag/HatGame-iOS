//
//  GameSyncManager.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import FirebaseDatabase
import Foundation
import Observation

@MainActor
@Observable
open class GameSyncManager {
    public internal(set) var isLoading: Bool = false
    public internal(set) var error: Error?

    private let firebaseService = FirebaseService.shared

    public init() {}

    // MARK: - Game initialization
    /// Sets up the very first `OnlineGameState` once all players have
    /// submitted their words. Picks team 0 as the starting team and the
    /// first player in that team as the explainer.
    open func initializeGame(
        for roomId: String,
        teams: [OnlineTeam],
        players: [OnlinePlayer],
        words: [OnlineWord],
        settings: GameSettings
    ) async throws -> OnlineGameState {
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

        try await firebaseService.updateGameState(state, forRoomId: roomId)
        return state
    }

    // MARK: - Turn lifecycle
    /// The explainer flips the room from `.teamPrep` to `.playing` and the
    /// server timestamps the timer start. All other clients compute their
    /// countdown off this anchor.
    open func startTurn(roomId: String, gameState: OnlineGameState) async throws {
        var next = gameState
        next.phase = .playing
        next.timerStartedAt = Date()
        try await firebaseService.updateGameState(next, forRoomId: roomId)
    }

    /// Active player marks the current word guessed: score++ for the
    /// current team in the current round, word removed from the pool,
    /// next word picked. If the pool is empty after this, currentWordId
    /// becomes nil and the explainer's local turn-end pathway fires.
    open func markWordGuessed(
        roomId: String,
        gameState: OnlineGameState,
        teams: [OnlineTeam]
    ) async throws {
        guard let wordId = gameState.currentWordId else { return }
        var next = gameState

        if let teamId = currentTeamId(state: gameState, teams: teams) {
            var perRound = next.scores[teamId] ?? [:]
            perRound[gameState.currentRound, default: 0] += 1
            next.scores[teamId] = perRound
        }

        next.remainingWordIds.removeAll { $0 == wordId }
        next.currentWordId = next.remainingWordIds.first
        try await firebaseService.updateGameState(next, forRoomId: roomId)
    }

    /// Skip moves the current word to the back of the remaining pool with
    /// no scoring effect. If only one word remains we no-op (parity with
    /// the offline `skipCurrentWord`).
    open func skipWord(roomId: String, gameState: OnlineGameState) async throws {
        guard gameState.isSkippingEnabled,
              let currentId = gameState.currentWordId,
              gameState.remainingWordIds.count > 1 else { return }
        var next = gameState
        next.remainingWordIds.removeAll { $0 == currentId }
        next.remainingWordIds.append(currentId)
        next.currentWordId = next.remainingWordIds.first
        try await firebaseService.updateGameState(next, forRoomId: roomId)
    }

    /// Called by the active player when the timer hits 0, they tap "give
    /// up", or when they've cleared the hat (currentWordId == nil).
    /// Transitions to `.turnResults` and clears the timer anchor.
    open func endTurn(roomId: String, gameState: OnlineGameState) async throws {
        var next = gameState
        next.phase = .turnResults
        next.timerStartedAt = nil
        try await firebaseService.updateGameState(next, forRoomId: roomId)
    }

    // MARK: - Phase advancement
    /// Single source of truth for moving the game forward after the
    /// turn-results screen. Decides whether the next slot is the next
    /// team's `.teamPrep`, the next round's `.roundResults`, or
    /// `.finished`.
    open func advanceAfterTurnResults(
        roomId: String,
        gameState: OnlineGameState,
        teams: [OnlineTeam],
        players: [OnlinePlayer]
    ) async throws {
        guard !teams.isEmpty else { return }
        var next = gameState

        if next.remainingWordIds.isEmpty {
            // Round complete. Surface the round results screen; rotation
            // happens when the host advances to the next round.
            next.phase = .roundResults
            try await firebaseService.updateGameState(next, forRoomId: roomId)
            return
        }

        // More words to play in this round — pass the hat to the next team.
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
        try await firebaseService.updateGameState(next, forRoomId: roomId)
    }

    /// Host-only. After the round results screen, advances to the next
    /// round (reshuffles all words) or finishes the game.
    open func advanceAfterRoundResults(
        roomId: String,
        gameState: OnlineGameState,
        teams: [OnlineTeam],
        players: [OnlinePlayer]
    ) async throws {
        var next = gameState

        guard let upcoming = gameState.currentRound.next else {
            // Round 3 just finished — wrap the game.
            next.phase = .finished
            try await firebaseService.updateGameState(next, forRoomId: roomId)
            try await firebaseService.updateRoomStatus(.finished, forRoomId: roomId)
            return
        }

        next.currentRound = upcoming
        next.remainingWordIds = gameState.allWordIds.shuffled()
        next.currentWordId = next.remainingWordIds.first

        // Keep the same team / explainer for continuity — they earned the
        // jump into the next round by being the one who cleared the hat.
        let team = teams[safe: next.currentTeamIndex]
        let teamPlayers = team.map { playersInTeam($0, allPlayers: players) } ?? []
        let explainerIndex = team.map { next.teamExplainerIndices[$0.id] ?? 0 } ?? 0
        next.activePlayerId = teamPlayers[safe: explainerIndex]?.id

        next.phase = .teamPrep
        next.timerStartedAt = nil
        try await firebaseService.updateGameState(next, forRoomId: roomId)
    }

    // MARK: - Helpers
    private func playersInTeam(_ team: OnlineTeam, allPlayers: [OnlinePlayer]) -> [OnlinePlayer] {
        // Prefer team.playerIds order (matches join order); fall back to a
        // filter on player.teamId for resilience to legacy data.
        if !team.playerIds.isEmpty {
            let lookup = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0) })
            return team.playerIds.compactMap { lookup[$0] }
        }
        return allPlayers.filter { $0.teamId == team.id }
    }

    private func currentTeamId(state: OnlineGameState, teams: [OnlineTeam]) -> String? {
        teams[safe: state.currentTeamIndex]?.id
    }
}

// MARK: - Array safe subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
