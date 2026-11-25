//
//  GameRecord.swift
//  HatGame
//

import Foundation

/// A game as History keeps it: who played, how each round scored, and — for
/// a pass-and-play game — every turn. Names and words are copied in, so a
/// record never depends on the game it came from.
nonisolated struct GameRecord: Codable, Sendable, Identifiable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = GameRecord.currentSchemaVersion
    let id: UUID
    let mode: Mode
    let outcome: Outcome
    /// When round one began; `nil` where the start wasn't known.
    let startedAt: Date?
    let endedAt: Date
    /// Rounds that began, one to three.
    let roundsPlayed: Int
    let settings: Settings
    /// In setup order; `ranking` orders them by score.
    let teams: [TeamResult]
    /// Empty for multiplayer games, which keep only scores.
    let turns: [TurnResult]
    /// Identifies a multiplayer game, so a results screen shown twice records it once.
    let sourceKey: String?
}

// MARK: - Nested types
nonisolated extension GameRecord {
    enum Mode: String, Codable, Sendable, CaseIterable {
        case passAndPlay
        case nearby
        case online
    }

    enum Outcome: String, Codable, Sendable {
        /// All three rounds were played.
        case finished
        /// The game was ended before the last round was over.
        case endedEarly
    }

    struct Settings: Codable, Sendable, Equatable {
        let roundDuration: Int
        let wordCount: Int
        let isSkippingEnabled: Bool
        let skipPenalty: Int
    }

    struct TeamResult: Codable, Sendable, Identifiable, Equatable {
        let id: String
        let name: String
        let color: TeamColor
        let players: [String]
        /// Points per round, rounds one to three; rounds not played score zero.
        let roundScores: [Int]

        var total: Int { roundScores.reduce(0, +) }

        func score(in round: Int) -> Int {
            roundScores.indices.contains(round - 1) ? roundScores[round - 1] : 0
        }
    }

    struct TurnResult: Codable, Sendable, Identifiable, Equatable {
        let id: Int
        let round: Int
        let teamId: String
        let explainer: String?
        let words: [String]
        let skipped: Int
        let points: Int
        let endReason: PlayCompletionReason
        let secondsUsed: Int?
    }
}

// MARK: - Building from a game
nonisolated extension GameRecord {
    /// The record of a pass-and-play game at its end. `endedAt` is when it
    /// finished, or when it was ended early.
    init(state: GameState, outcome: Outcome, endedAt: Date, id: UUID = UUID()) {
        let scoreboard = state.scoreboard
        let names = Dictionary(
            state.teams.flatMap(\.players).map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        let words = Dictionary(state.words.map { ($0.id, $0.text) }, uniquingKeysWith: { first, _ in first })
        let penalty = state.settings.skipPenalty

        self.init(
            id: id,
            mode: .passAndPlay,
            outcome: outcome,
            startedAt: state.startedAt,
            endedAt: endedAt,
            roundsPlayed: max(1, state.startedRounds.count),
            settings: Settings(
                roundDuration: state.settings.roundDuration,
                wordCount: state.words.count,
                isSkippingEnabled: state.settings.isSkippingEnabled,
                skipPenalty: penalty
            ),
            teams: state.teams.map { team in
                TeamResult(
                    id: team.id.uuidString,
                    name: team.name,
                    color: team.teamColor,
                    players: team.players.map(\.name),
                    roundScores: GameRound.allCases.map { scoreboard.score(for: team, in: $0) }
                )
            },
            turns: state.turnLog.enumerated().map { index, entry in
                TurnResult(
                    id: index,
                    round: entry.round.rawValue,
                    teamId: entry.teamId.uuidString,
                    explainer: entry.explainerId.flatMap { names[$0] },
                    words: entry.guessedWordIds.compactMap { words[$0] },
                    skipped: entry.skippedCount,
                    points: entry.guessedWordIds.count - entry.skippedCount * penalty,
                    endReason: entry.endReason,
                    secondsUsed: entry.secondsUsed
                )
            },
            sourceKey: nil
        )
    }
}
