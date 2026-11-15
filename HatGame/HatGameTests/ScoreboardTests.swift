//
//  ScoreboardTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import HatGame
import Testing

@Suite("Scoreboard")
struct ScoreboardTests {
    private let teams = Fixtures.teams(count: 3)

    @Test("Totals sum every round")
    func totalsSumRounds() {
        let board = makeBoard([
            .first: [teams[0].id: 2, teams[1].id: 1],
            .second: [teams[0].id: 1],
            .third: [teams[0].id: 3, teams[2].id: 4],
        ])

        #expect(board.score(for: teams[0], in: .first) == 2)
        #expect(board.score(for: teams[2], in: .second) == 0)
        #expect(board.totalScore(for: teams[0]) == 6)
        #expect(board.totalScore(for: teams[1]) == 1)
        #expect(board.totalScore(for: teams[2]) == 4)
        #expect(board.hasAnyScore)
    }

    @Test("Rankings go highest first; ties keep setup order")
    func tiesKeepTeamOrder() {
        let board = makeBoard([
            .first: [teams[1].id: 2, teams[2].id: 2],
            .second: [teams[0].id: 1, teams[1].id: 1, teams[2].id: 1],
        ])

        #expect(board.ranking(in: .first).map(\.id) == [teams[1].id, teams[2].id, teams[0].id])
        #expect(board.ranking(in: .second).map(\.id) == teams.map(\.id))
        #expect(board.totalRanking().map(\.id) == [teams[1].id, teams[2].id, teams[0].id])
    }

    @Test("Teams tied on the top total are co-winners")
    func coWinners() {
        let board = makeBoard([.first: [teams[0].id: 3, teams[2].id: 3, teams[1].id: 1]])

        #expect(board.winners.map(\.id) == [teams[0].id, teams[2].id])
    }

    @Test("With no scores every team ties; with no teams there are no winners")
    func emptyBoards() {
        #expect(makeBoard([:]).winners.count == 3)
        #expect(!makeBoard([:]).hasAnyScore)
        #expect(Scoreboard(teams: [], scores: [:]).winners.isEmpty)
    }

    @Test("A renamed team keeps its score")
    func renamedTeamKeepsScore() {
        var renamed = teams
        renamed[0].name = "Renamed"
        let scores = makeScores([.first: [teams[0].id: 2]])

        let board = Scoreboard(teams: renamed, scores: scores)

        #expect(board.totalScore(for: renamed[0]) == 2)
        #expect(board.totalRanking().first?.name == "Renamed")
    }

    @Test("Rematch starts the scoreboard from zero")
    func rematchResetsScores() {
        let finished = Fixtures.started().clearingRound().clearingRound().clearingRound()
        #expect(finished.scoreboard.hasAnyScore)

        let rematch = GameRules.rematch(finished)

        #expect(!rematch.scoreboard.hasAnyScore)
        #expect(rematch.teams.allSatisfy { rematch.scoreboard.totalScore(for: $0) == 0 })
    }
}

// MARK: - Helpers
private extension ScoreboardTests {
    func makeBoard(_ counts: [GameRound: [Team.ID: Int]]) -> Scoreboard {
        Scoreboard(teams: teams, scores: makeScores(counts))
    }

    func makeScores(_ counts: [GameRound: [Team.ID: Int]]) -> [GameRound: [Team.ID: [Word.ID]]] {
        counts.mapValues { perTeam in
            perTeam.mapValues { count in (0..<count).map { _ in UUID() } }
        }
    }
}
