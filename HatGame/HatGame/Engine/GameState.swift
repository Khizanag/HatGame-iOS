//
//  GameState.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// The complete, persistable state of a single-device game. Pure data —
/// every change goes through `GameRules`.
nonisolated struct GameState: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = GameState.currentSchemaVersion
    var settings: Settings
    var teams: [Team]
    var words: [Word]
    var phase: Phase = .setup
    var round: GameRound = .first
    var currentTeamId: Team.ID?
    var remainingWordIds: [Word.ID] = []
    var currentWordId: Word.ID?
    /// Index into the team's `players` of its current explainer.
    var explainerIndices: [Team.ID: Int] = [:]
    /// Teams that have played at least once; their explainer only rotates.
    var lockedTeamIds: Set<Team.ID> = []
    /// Leftover seconds a team carries into its next turn after emptying the hat.
    var carryOverSeconds: [Team.ID: Int] = [:]
    /// Guessed words per round and team. Keyed by id, so renaming a team keeps its score.
    var scores: [GameRound: [Team.ID: [Word.ID]]] = [:]
    var turn: Turn?

    init(settings: Settings, teams: [Team], words: [Word]) {
        self.settings = settings
        self.teams = teams
        self.words = words
    }
}

// MARK: - Nested types
// Nested rather than top-level: `GamePhase` and `GameSettings` already name
// online-play types in the Networking module.
nonisolated extension GameState {
    /// Where a single-device game is in its loop.
    enum Phase: String, Codable, Sendable {
        /// Built from setup but not started yet (also the state after a rematch).
        case setup
        /// Announcing the team that is up; its explainer is chosen or confirmed.
        case nextTeam
        /// A timed turn is in progress (possibly paused).
        case playing
        /// A turn just ended; its results are on screen.
        case turnResults
        /// The third round is over.
        case finished

        /// True while a game is underway and worth restoring after a relaunch.
        var isInProgress: Bool {
            switch self {
            case .nextTeam, .playing, .turnResults: true
            case .setup, .finished: false
            }
        }
    }

    /// Per-game settings chosen during setup.
    struct Settings: Codable, Sendable, Equatable {
        /// Full turn length, in seconds.
        var roundDuration: Int
        var isSkippingEnabled: Bool
    }

    /// The turn in progress, or the one whose results are showing.
    struct Turn: Codable, Sendable, Equatable {
        let teamId: Team.ID
        /// Time left on the clock as of the last snapshot. The engine's live
        /// clock is authoritative while the turn runs; this is what gets persisted.
        var remaining: Duration
        var isPaused: Bool = false
        var guessedWordIds: [Word.ID] = []
        var endReason: PlayCompletionReason?
    }
}

// MARK: - Derived state
nonisolated extension GameState {
    var currentTeam: Team? {
        currentTeamId.flatMap(team(withId:))
    }

    var currentWord: Word? {
        currentWordId.flatMap(word(withId:))
    }

    var remainingWordCount: Int {
        remainingWordIds.count
    }

    var isFinished: Bool {
        phase == .finished
    }

    /// Words guessed in the current (or just-ended) turn, in guess order.
    var turnGuessedWords: [Word] {
        (turn?.guessedWordIds ?? []).compactMap(word(withId:))
    }

    /// Rounds that have begun, in order — all three once the game is over.
    var startedRounds: [GameRound] {
        guard phase != .finished else { return GameRound.allCases }
        guard phase != .setup else { return [] }
        return GameRound.allCases.filter { $0.rawValue <= round.rawValue }
    }

    var scoreboard: Scoreboard {
        Scoreboard(teams: teams, scores: scores)
    }

    /// Whether the state can be played from. A saved game that decodes but
    /// fails this (a missing team, a turn without a word) would leave the loop
    /// screen with nothing to show, so it is discarded like a corrupt file.
    var isConsistent: Bool {
        let wordIds = Set(words.map(\.id))
        let scoredIds = scores.values.flatMap(\.values).flatMap { $0 }
        let explainersValid = explainerIndices.allSatisfy { teamId, index in
            team(withId: teamId)?.players.indices.contains(index) ?? false
        }
        guard Set(remainingWordIds).isSubset(of: wordIds),
              Set(scoredIds).isSubset(of: wordIds),
              explainersValid
        else { return false }

        switch phase {
        case .setup, .finished:
            return true
        case .nextTeam:
            return currentTeam != nil && !remainingWordIds.isEmpty
        case .playing:
            guard let currentTeamId, currentTeam != nil, turn?.teamId == currentTeamId,
                  let currentWordId
            else { return false }
            return remainingWordIds.contains(currentWordId)
        case .turnResults:
            guard let currentTeamId, currentTeam != nil else { return false }
            return turn?.teamId == currentTeamId
        }
    }

    func team(withId id: Team.ID) -> Team? {
        teams.first { $0.id == id }
    }

    func word(withId id: Word.ID) -> Word? {
        words.first { $0.id == id }
    }

    /// Whether the team still picks its explainer by hand (it hasn't played yet).
    func canSelectExplainer(for team: Team) -> Bool {
        !lockedTeamIds.contains(team.id)
    }

    func explainerIndex(for team: Team) -> Int? {
        explainerIndices[team.id]
    }

    func explainer(for team: Team) -> Player? {
        explainerIndices[team.id].flatMap { team.players[safe: $0] }
    }

    func guessers(for team: Team) -> [Player] {
        guard let explainerIndex = explainerIndices[team.id] else {
            return Array(team.players.dropFirst())
        }
        return team.players.enumerated()
            .filter { $0.offset != explainerIndex }
            .map(\.element)
    }
}
