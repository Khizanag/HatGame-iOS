//
//  GameRulesTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

/// Two uneven teams: A has three players (a1 hosts), B has two.
private enum Table {
    static let host = "a1"
    static let words = ["w1", "w2", "w3", "w4"]
    static let teams = [
        Fixture.team("A", players: ["a1", "a2", "a3"], createdOffset: 0),
        Fixture.team("B", players: ["b1", "b2"], createdOffset: 1),
    ]
    static let players = [
        Fixture.player("a1", team: "A", joinedOffset: 0),
        Fixture.player("a2", team: "A", joinedOffset: 1),
        Fixture.player("a3", team: "A", joinedOffset: 2),
        Fixture.player("b1", team: "B", joinedOffset: 3),
        Fixture.player("b2", team: "B", joinedOffset: 4),
    ]

    static func context(
        now: Date = Fixture.epoch,
        players: [OnlinePlayer] = players
    ) -> GameContext {
        GameContext(hostId: host, teams: teams, players: players, now: now)
    }

    static func initial(words: [String] = words, isSkippingEnabled: Bool = true) throws -> OnlineGameState {
        let settings = GameSettings(roundDuration: 60, isSkippingEnabled: isSkippingEnabled)
        return try #require(
            GameRules.initialState(teams: teams, players: players, wordIds: words, settings: settings)
        )
    }

    static func playing(words: [String] = words, isSkippingEnabled: Bool = true) throws -> OnlineGameState {
        let state = try initial(words: words, isSkippingEnabled: isSkippingEnabled)
        return try #require(GameRules.startTurn(state, now: Fixture.epoch))
    }

    /// Plays one turn for the current team: start, time's up, continue.
    static func passTurn(_ state: OnlineGameState) throws -> OnlineGameState {
        let started = try #require(GameRules.startTurn(state, now: Fixture.epoch))
        let ended = try #require(GameRules.endTurn(started))
        return try #require(GameRules.advanceAfterTurnResults(ended, teams: teams, players: players))
    }

    /// Guesses every remaining word in the current turn.
    static func clearHat(_ state: OnlineGameState) throws -> OnlineGameState {
        var current = try #require(GameRules.startTurn(state, now: Fixture.epoch))
        while let wordId = current.currentWordId, current.phase == .playing {
            current = try #require(
                GameRules.markGuessed(current, expectedWordId: wordId, teams: teams, now: Fixture.epoch)
            )
        }
        return current
    }
}

// MARK: - Setup
@Suite("GameRules setup")
struct GameRulesSetupTests {
    @Test("Initial state starts team A with its first player explaining")
    func initialState() throws {
        let state = try Table.initial()

        #expect(state.phase == .teamPrep)
        #expect(state.currentRound == .first)
        #expect(state.currentTeamIndex == 0)
        #expect(state.activePlayerId == "a1")
        #expect(state.currentWordId == "w1")
        #expect(state.remainingWordIds == Table.words)
        #expect(state.allWordIds == Table.words)
        #expect(state.getTotalScore(for: "A") == 0)
        #expect(state.teamExplainerIndices == ["A": 0, "B": 0])
        #expect(state.roundDuration == 60)
    }

    @Test("Initial state needs teams and words")
    func initialStateRequiresTeamsAndWords() {
        let settings = GameSettings()
        let players = Table.players

        #expect(GameRules.initialState(teams: [], players: players, wordIds: ["w"], settings: settings) == nil)
        #expect(GameRules.initialState(teams: Table.teams, players: players, wordIds: [], settings: settings) == nil)
    }
}

// MARK: - Turn
@Suite("GameRules turn")
struct GameRulesTurnTests {
    @Test("Start turn anchors the timer")
    func startTurn() throws {
        let state = try Table.playing()

        #expect(state.phase == .playing)
        #expect(state.timerStartedAt == Fixture.epoch)
        #expect(GameRules.deadline(state) == Fixture.epoch.addingTimeInterval(60))
    }

    @Test("Start turn is rejected outside team prep or without an explainer")
    func startTurnPreconditions() throws {
        let playing = try Table.playing()
        var noExplainer = try Table.initial()
        noExplainer.activePlayerId = nil
        var emptyHat = try Table.initial()
        emptyHat.remainingWordIds = []

        #expect(GameRules.startTurn(playing, now: Fixture.epoch) == nil)
        #expect(GameRules.startTurn(noExplainer, now: Fixture.epoch) == nil)
        #expect(GameRules.startTurn(emptyHat, now: Fixture.epoch) == nil)
    }

    @Test("Got it scores the current team and draws the next word")
    func markGuessed() throws {
        let state = try Table.playing()

        let next = try #require(
            GameRules.markGuessed(state, expectedWordId: "w1", teams: Table.teams, now: Fixture.epoch)
        )

        #expect(next.getScore(for: "A", in: .first) == 1)
        #expect(next.getScore(for: "B", in: .first) == 0)
        #expect(next.remainingWordIds == ["w2", "w3", "w4"])
        #expect(next.currentWordId == "w2")
        #expect(next.phase == .playing)
    }

    @Test("A double tap on the same word scores once")
    func doubleTapScoresOnce() throws {
        let state = try Table.playing()
        let once = try #require(
            GameRules.markGuessed(state, expectedWordId: "w1", teams: Table.teams, now: Fixture.epoch)
        )

        let twice = GameRules.markGuessed(once, expectedWordId: "w1", teams: Table.teams, now: Fixture.epoch)

        #expect(twice == nil)
        #expect(once.getScore(for: "A", in: .first) == 1)
    }

    @Test("A guess after the deadline grace is rejected; within it, accepted")
    func guessDeadline() throws {
        let state = try Table.playing()
        let withinGrace = Fixture.epoch.addingTimeInterval(60 + GameRules.guessGraceSeconds)
        let pastGrace = withinGrace.addingTimeInterval(0.5)

        #expect(GameRules.markGuessed(state, expectedWordId: "w1", teams: Table.teams, now: withinGrace) != nil)
        #expect(GameRules.markGuessed(state, expectedWordId: "w1", teams: Table.teams, now: pastGrace) == nil)
    }

    @Test("A guess that arrives after the turn ended does not rewind it")
    func guessAfterTurnEnded() throws {
        let ended = try #require(GameRules.endTurn(try Table.playing()))

        #expect(GameRules.markGuessed(ended, expectedWordId: "w1", teams: Table.teams, now: Fixture.epoch) == nil)
    }

    @Test("Guessing the last word empties the hat and ends the turn")
    func lastWordEndsTurn() throws {
        let state = try Table.playing(words: ["only"])

        let next = try #require(
            GameRules.markGuessed(state, expectedWordId: "only", teams: Table.teams, now: Fixture.epoch)
        )

        #expect(next.phase == .turnResults)
        #expect(next.timerStartedAt == nil)
        #expect(next.currentWordId == nil)
        #expect(next.remainingWordIds.isEmpty)
    }

    @Test("Skip moves the word to the back without scoring")
    func skip() throws {
        let state = try Table.playing()

        let next = try #require(GameRules.skip(state, expectedWordId: "w1"))

        #expect(next.remainingWordIds == ["w2", "w3", "w4", "w1"])
        #expect(next.currentWordId == "w2")
        #expect(next.getTotalScore(for: "A") == 0)
    }

    @Test("Skip needs skipping enabled, another word, the right word, and a running turn")
    func skipPreconditions() throws {
        let disabled = try Table.playing(isSkippingEnabled: false)
        let lastWord = try Table.playing(words: ["only"])
        let running = try Table.playing()
        let prep = try Table.initial()

        #expect(GameRules.skip(disabled, expectedWordId: "w1") == nil)
        #expect(GameRules.skip(lastWord, expectedWordId: "only") == nil)
        #expect(GameRules.skip(running, expectedWordId: "w2") == nil)
        #expect(GameRules.skip(prep, expectedWordId: "w1") == nil)
    }

    @Test("End turn closes a running turn or forfeits one in team prep")
    func endTurn() throws {
        let fromPlaying = try #require(GameRules.endTurn(try Table.playing()))
        let fromPrep = try #require(GameRules.endTurn(try Table.initial()))

        #expect(fromPlaying.phase == .turnResults)
        #expect(fromPlaying.timerStartedAt == nil)
        #expect(fromPrep.phase == .turnResults)
        #expect(GameRules.endTurn(fromPlaying) == nil)
    }

    @Test("Transitions refuse states written by a newer build")
    func unsupportedStatesAreRejected() throws {
        var state = try Table.playing()
        state.phase = .unsupported
        var round = try Table.playing()
        round.currentRound = .unsupported

        #expect(GameRules.endTurn(state) == nil)
        #expect(GameRules.skip(round, expectedWordId: "w1") == nil)
        #expect(GameRules.reduce(state, .startTurn, context: Table.context()) == nil)
    }
}

// MARK: - Advancement
@Suite("GameRules advancement")
struct GameRulesAdvancementTests {
    @Test("Turn results pass the hat to the next team and rotate the previous explainer")
    func passesToNextTeam() throws {
        let next = try Table.passTurn(try Table.initial())

        #expect(next.phase == .teamPrep)
        #expect(next.currentTeamIndex == 1)
        #expect(next.activePlayerId == "b1")
        #expect(next.explainerIndex(for: "A") == 1)
        #expect(next.explainerIndex(for: "B") == 0)
        #expect(next.timerStartedAt == nil)
    }

    @Test("Uneven teams rotate independently and the team order wraps around")
    func unevenRotationWraps() throws {
        var state = try Table.initial()
        var explainers: [String] = []
        for _ in 0..<10 {
            explainers.append(try #require(state.activePlayerId))
            state = try Table.passTurn(state)
        }

        #expect(explainers == ["a1", "b1", "a2", "b2", "a3", "b1", "a1", "b2", "a2", "b1"])
    }

    @Test("Emptying the hat ends the round without rotating the explainer")
    func emptyHatEndsRound() throws {
        let cleared = try Table.clearHat(try Table.initial())

        let results = try #require(
            GameRules.advanceAfterTurnResults(cleared, teams: Table.teams, players: Table.players)
        )

        #expect(results.phase == .roundResults)
        #expect(results.currentTeamIndex == 0)
        #expect(results.explainerIndex(for: "A") == 0)
        #expect(results.getScore(for: "A", in: .first) == 4)
    }

    @Test("The next round refills the hat and keeps the team that emptied it")
    func nextRoundKeepsTeam() throws {
        let afterTurn = try Table.passTurn(try Table.initial())
        let cleared = try Table.clearHat(afterTurn)
        let roundResults = try #require(
            GameRules.advanceAfterTurnResults(cleared, teams: Table.teams, players: Table.players)
        )

        let next = try #require(
            GameRules.advanceAfterRoundResults(
                roundResults,
                teams: Table.teams,
                players: Table.players,
                shuffle: { $0.reversed() }
            )
        )

        #expect(next.currentRound == .second)
        #expect(next.phase == .teamPrep)
        #expect(next.currentTeamIndex == 1)
        #expect(next.activePlayerId == "b1")
        #expect(next.remainingWordIds == Table.words.reversed())
        #expect(next.currentWordId == "w4")
        #expect(next.getScore(for: "B", in: .first) == 4)
        #expect(next.getScore(for: "B", in: .second) == 0)
    }

    @Test("Round three's results finish the game")
    func roundThreeFinishes() throws {
        var state = try Table.initial()
        for _ in OnlineGameRound.allCases {
            let cleared = try Table.clearHat(state)
            let results = try #require(
                GameRules.advanceAfterTurnResults(cleared, teams: Table.teams, players: Table.players)
            )
            state = try #require(
                GameRules.advanceAfterRoundResults(results, teams: Table.teams, players: Table.players)
            )
        }

        #expect(state.phase == .finished)
        #expect(state.currentRound == .third)
        #expect(state.getTotalScore(for: "A") == 12)
    }

    @Test("Advancing from the wrong phase is rejected")
    func advancePreconditions() throws {
        let prep = try Table.initial()

        #expect(GameRules.advanceAfterTurnResults(prep, teams: Table.teams, players: Table.players) == nil)
        #expect(GameRules.advanceAfterTurnResults(
            try #require(GameRules.endTurn(prep)),
            teams: [],
            players: Table.players
        ) == nil)
        #expect(GameRules.advanceAfterRoundResults(prep, teams: Table.teams, players: Table.players) == nil)
    }

    @Test("A team with no players leaves the explainer empty")
    func emptyTeamHasNoExplainer() throws {
        let teams = [Table.teams[0], Fixture.team("C")]
        let state = try #require(GameRules.endTurn(try Table.initial()))

        let next = try #require(GameRules.advanceAfterTurnResults(state, teams: teams, players: Table.players))

        #expect(next.currentTeamIndex == 1)
        #expect(next.activePlayerId == nil)
    }
}

// MARK: - Queries
@Suite("GameRules queries")
struct GameRulesQueryTests {
    @Test("Team membership follows player.teamId; playerIds only orders it")
    func playersInTeam() {
        let team = Fixture.team("A", players: ["a3", "ghost", "a3", "a1"])
        let players = [
            Fixture.player("a1", team: "A", joinedOffset: 0),
            Fixture.player("a2", team: "A", joinedOffset: 1),
            Fixture.player("a3", team: "A", joinedOffset: 2),
            Fixture.player("b1", team: "B", joinedOffset: 3),
        ]

        let members = GameRules.playersInTeam(team, allPlayers: players).map(\.id)

        #expect(members == ["a3", "a1", "a2"])
    }

    @Test("An explainer index past the team size wraps")
    func explainerWraps() throws {
        var state = try Table.initial()
        state.teamExplainerIndices["B"] = 5

        let explainer = GameRules.explainer(for: Table.teams[1], state: state, players: Table.players)

        #expect(explainer?.id == "b2")
    }

    @Test("The explainer is away when missing, unknown, or disconnected")
    func activePlayerAway() throws {
        var state = try Table.initial()
        let offline = Table.players.map { Fixture.player($0.id, team: $0.teamId, isConnected: $0.id != "a1") }

        #expect(!GameRules.isActivePlayerAway(state, players: Table.players))
        #expect(GameRules.isActivePlayerAway(state, players: offline))
        state.activePlayerId = "nobody"
        #expect(GameRules.isActivePlayerAway(state, players: Table.players))
        state.activePlayerId = nil
        #expect(GameRules.isActivePlayerAway(state, players: Table.players))
    }

    @Test("Current team is nil for an out-of-range index")
    func currentTeamOutOfRange() throws {
        var state = try Table.initial()
        state.currentTeamIndex = 7

        #expect(GameRules.currentTeam(state, teams: Table.teams) == nil)
    }
}
