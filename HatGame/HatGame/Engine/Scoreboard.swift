//
//  Scoreboard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

/// Read-only standings over a game's scores. One point per guessed word,
/// less `skipPenalty` per skipped word, so a score can go below zero. Ties
/// keep the teams' setup order so rankings are stable.
nonisolated struct Scoreboard: Sendable {
    let teams: [Team]
    let scores: [GameRound: [Team.ID: [Word.ID]]]
    var skipCounts: [GameRound: [Team.ID: Int]] = [:]
    var skipPenalty = 0

    func score(for team: Team, in round: GameRound) -> Int {
        let guessed = scores[round]?[team.id]?.count ?? 0
        let skipped = skipCounts[round]?[team.id] ?? 0
        return guessed - skipped * skipPenalty
    }

    func totalScore(for team: Team) -> Int {
        GameRound.allCases.reduce(0) { $0 + score(for: team, in: $1) }
    }

    /// Teams ranked by their score in `round`, highest first.
    func ranking(in round: GameRound) -> [Team] {
        ranked { score(for: $0, in: round) }
    }

    /// Teams ranked by total score across all rounds, highest first.
    func totalRanking() -> [Team] {
        ranked(by: totalScore(for:))
    }

    /// Every team sharing the highest total — more than one means co-winners.
    var winners: [Team] {
        guard let top = teams.map(totalScore(for:)).max() else { return [] }
        return teams.filter { totalScore(for: $0) == top }
    }

    /// Whether any team has guessed or been penalized yet.
    var hasAnyScore: Bool {
        teams.contains { team in
            GameRound.allCases.contains { round in
                !(scores[round]?[team.id] ?? []).isEmpty || (skipCounts[round]?[team.id] ?? 0) * skipPenalty > 0
            }
        }
    }
}

// MARK: - Private
nonisolated private extension Scoreboard {
    func ranked(by score: (Team) -> Int) -> [Team] {
        teams.enumerated()
            .sorted { lhs, rhs in
                let lhsScore = score(lhs.element)
                let rhsScore = score(rhs.element)
                return lhsScore == rhsScore ? lhs.offset < rhs.offset : lhsScore > rhsScore
            }
            .map(\.element)
    }
}
