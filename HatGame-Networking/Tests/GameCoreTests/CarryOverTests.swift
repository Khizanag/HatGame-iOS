//
//  CarryOverTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("Online carry-over")
struct CarryOverTests {
    private static let teams = [
        Fixture.team("A", players: ["a1", "a2"]),
        Fixture.team("B", players: ["b1", "b2"], createdOffset: 1),
    ]
    private static let players = [
        Fixture.player("a1", team: "A"),
        Fixture.player("a2", team: "A", joinedOffset: 1),
        Fixture.player("b1", team: "B", joinedOffset: 2),
        Fixture.player("b2", team: "B", joinedOffset: 3),
    ]

    /// Team A on the clock with the last word in the hat.
    private static func lastWordInPlay() throws -> OnlineGameState {
        let state = try #require(
            OnlineGameRules.initialState(
                teams: teams,
                players: players,
                wordIds: ["w1"],
                settings: GameSettings(roundDuration: 60),
                startingTeamIndex: 0
            )
        )
        return try #require(OnlineGameRules.startTurn(state, teams: teams, now: Fixture.epoch))
    }

    private static func emptyHat(secondsIn: TimeInterval) throws -> OnlineGameState {
        try #require(
            OnlineGameRules.markGuessed(
                try lastWordInPlay(),
                expectedWordId: "w1",
                teams: teams,
                now: Fixture.epoch.addingTimeInterval(secondsIn)
            )
        )
    }

    @Test("Emptying the hat keeps the seconds the countdown showed")
    func carriesDisplayedSeconds() throws {
        let state = try Self.emptyHat(secondsIn: 47.6)

        #expect(state.carryOverSeconds == ["A": 13])
        #expect(state.turnSeconds == nil)
        #expect(state.phase == .turnResults)
    }

    @Test("A guess in the grace period after zero still carries one second")
    func graceCarriesOneSecond() throws {
        let state = try Self.emptyHat(secondsIn: 61)

        #expect(state.carryOverSeconds == ["A": 1])
    }

    @Test("Carry-over rounds up and never drops below one", arguments: [
        (12.01, 13), (12.0, 12), (0.2, 1), (-1.5, 1),
    ])
    func carryOverRounding(remaining: TimeInterval, expected: Int) {
        #expect(OnlineGameRules.carryOverSeconds(remaining: remaining) == expected)
    }

    @Test("The team that emptied the hat starts the next round on its leftover time")
    func nextRoundUsesCarryOver() throws {
        let emptied = try Self.emptyHat(secondsIn: 47.6)
        let results = try #require(
            OnlineGameRules.advanceAfterTurnResults(emptied, teams: Self.teams, players: Self.players)
        )
        let nextRound = try #require(
            OnlineGameRules.advanceAfterRoundResults(results, teams: Self.teams, players: Self.players)
        )

        let started = try #require(OnlineGameRules.startTurn(nextRound, teams: Self.teams, now: Fixture.epoch))

        #expect(nextRound.currentTeamIndex == 0)
        #expect(started.turnSeconds == 13)
        #expect(OnlineGameRules.deadline(started) == Fixture.epoch.addingTimeInterval(13))
        #expect(started.carryOverSeconds.isEmpty)
    }

    @Test("Every other team gets a full timer")
    func otherTeamsGetFullTimer() throws {
        var state = try Self.lastWordInPlay()
        state.phase = .teamPrep
        state.currentTeamIndex = 1
        state.carryOverSeconds = ["A": 9]

        let started = try #require(OnlineGameRules.startTurn(state, teams: Self.teams, now: Fixture.epoch))

        #expect(started.turnSeconds == 60)
        #expect(started.carryOverSeconds == ["A": 9])
    }

    @Test("Only the emptying team's carry survives into the next round")
    func staleCarryIsDropped() throws {
        var state = OnlineGameState(allWordIds: ["w1"], phase: .roundResults)
        state.carryOverSeconds = ["A": 5, "B": 7]

        let next = try #require(
            OnlineGameRules.advanceAfterRoundResults(state, teams: Self.teams, players: Self.players)
        )

        #expect(next.carryOverSeconds == ["A": 5])
    }

    @Test("Finishing the game clears carry-over")
    func finishClears() throws {
        var state = OnlineGameState(currentRound: .third, allWordIds: ["w1"], phase: .roundResults)
        state.carryOverSeconds = ["A": 5]

        let finished = try #require(
            OnlineGameRules.advanceAfterRoundResults(state, teams: Self.teams, players: Self.players)
        )

        #expect(finished.phase == .finished)
        #expect(finished.carryOverSeconds.isEmpty)
    }

    @Test("Ending a turn on the timer carries nothing")
    func timerEndCarriesNothing() throws {
        let ended = try #require(OnlineGameRules.endTurn(try Self.lastWordInPlay()))

        #expect(ended.carryOverSeconds.isEmpty)
        #expect(ended.turnSeconds == nil)
    }

    @Test("A forfeited carried turn leaves the team a full timer for its next turn")
    func forfeitDropsCarryOver() throws {
        let emptied = try Self.emptyHat(secondsIn: 59)
        let results = try #require(
            OnlineGameRules.advanceAfterTurnResults(emptied, teams: Self.teams, players: Self.players)
        )
        let nextRound = try #require(
            OnlineGameRules.advanceAfterRoundResults(results, teams: Self.teams, players: Self.players) { _ in
                ["w1", "w2"]
            }
        )
        #expect(nextRound.carryOverSeconds == ["A": 1])

        let forfeited = try #require(OnlineGameRules.endTurn(nextRound))
        let passed = try #require(
            OnlineGameRules.advanceAfterTurnResults(forfeited, teams: Self.teams, players: Self.players)
        )
        #expect(passed.carryOverSeconds.isEmpty)

        let bTurn = try #require(OnlineGameRules.startTurn(passed, teams: Self.teams, now: Fixture.epoch))
        let bEnded = try #require(OnlineGameRules.endTurn(bTurn))
        let backToA = try #require(
            OnlineGameRules.advanceAfterTurnResults(bEnded, teams: Self.teams, players: Self.players)
        )
        let aTurn = try #require(OnlineGameRules.startTurn(backToA, teams: Self.teams, now: Fixture.epoch))

        #expect(aTurn.currentTeamIndex == 0)
        #expect(aTurn.turnSeconds == 60)
    }

    @Test("Carry-over survives a Firebase round trip")
    func roundTrip() throws {
        let state = OnlineGameState(carryOverSeconds: ["A": 13], turnSeconds: 13)

        let decoded = try Fixture.firebaseRoundTrip(state)

        #expect(decoded.carryOverSeconds == ["A": 13])
        #expect(decoded.turnSeconds == 13)
    }
}
