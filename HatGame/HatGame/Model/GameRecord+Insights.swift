//
//  GameRecord+Insights.swift
//  HatGame
//

import Foundation

// MARK: - Standings
nonisolated extension GameRecord {
    /// Teams by total, highest first; ties keep setup order.
    var ranking: [TeamResult] {
        teams.enumerated()
            .sorted { lhs, rhs in
                lhs.element.total == rhs.element.total
                    ? lhs.offset < rhs.offset
                    : lhs.element.total > rhs.element.total
            }
            .map(\.element)
    }

    /// Every team sharing the top total; more than one is a tie.
    var winners: [TeamResult] {
        guard let top = teams.map(\.total).max() else { return [] }
        return teams.filter { $0.total == top }
    }

    var isTie: Bool { winners.count > 1 }

    /// Points between first and second place; `nil` for a tie or a lone team.
    var winningMargin: Int? {
        let ranked = ranking
        guard ranked.count > 1, !isTie else { return nil }
        return ranked[0].total - ranked[1].total
    }

    /// The team's place, counting tied teams as sharing one.
    func rank(of team: TeamResult) -> Int {
        teams.filter { $0.total > team.total }.count + 1
    }

    func team(withId id: String) -> TeamResult? {
        teams.first { $0.id == id }
    }
}

// MARK: - Numbers
nonisolated extension GameRecord {
    /// From the first turn to the end; `nil` when the start wasn't known.
    var duration: TimeInterval? {
        guard let startedAt else { return nil }
        let seconds = endedAt.timeIntervalSince(startedAt)
        return seconds > 0 ? seconds : nil
    }

    var wordsGuessed: Int { turns.reduce(0) { $0 + $1.words.count } }

    var skips: Int { turns.reduce(0) { $0 + $1.skipped } }

    var hasTurns: Bool { !turns.isEmpty }

    func turns(in round: Int) -> [TurnResult] {
        turns.filter { $0.round == round }
    }
}

// MARK: - Highlights
nonisolated extension GameRecord {
    struct ExplainerStats: Identifiable, Equatable {
        let name: String
        let teamId: String
        var words = 0
        var turns = 0
        var id: String { "\(teamId)-\(name)" }
    }

    /// Every explainer with what they got across, most words first; ties
    /// keep the order they first explained in.
    var explainers: [ExplainerStats] {
        var stats: [ExplainerStats] = []
        for turn in turns {
            guard let name = turn.explainer else { continue }
            if let index = stats.firstIndex(where: { $0.name == name && $0.teamId == turn.teamId }) {
                stats[index].words += turn.words.count
                stats[index].turns += 1
            } else {
                stats.append(ExplainerStats(name: name, teamId: turn.teamId, words: turn.words.count, turns: 1))
            }
        }
        return stats.enumerated()
            .sorted { lhs, rhs in
                lhs.element.words == rhs.element.words
                    ? lhs.offset < rhs.offset
                    : lhs.element.words > rhs.element.words
            }
            .map(\.element)
    }

    /// The explainer who got the most words across; `nil` before any were.
    var bestExplainer: ExplainerStats? {
        explainers.first { $0.words > 0 }
    }

    /// The turn that guessed the most words; the earliest wins a tie.
    var bestTurn: TurnResult? {
        turns.reduce(nil) { best, turn in
            guard !turn.words.isEmpty else { return best }
            guard let best else { return turn }
            return turn.words.count > best.words.count ? turn : best
        }
    }

    /// Words per explainer on a team, in the order they first explained.
    func explainers(on team: TeamResult) -> [ExplainerStats] {
        let stats = explainers.filter { $0.teamId == team.id }
        return team.players.compactMap { name in stats.first { $0.name == name } }
    }
}
