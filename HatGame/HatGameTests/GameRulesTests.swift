//
//  GameRulesTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

@testable import HatGame
import Testing

@Suite("Game rules")
struct GameRulesTests {
    private var generator = SeededGenerator()

    // MARK: - Start
    @Test("Start puts the chosen team up in round one with a full hat")
    mutating func startBeginsRoundOne() {
        let setup = Fixtures.state()

        let state = GameRules.start(setup, startingTeamIndex: 1, using: &generator)

        #expect(state.phase == .nextTeam)
        #expect(state.round == .first)
        #expect(state.currentTeamId == setup.teams[1].id)
        #expect(Set(state.remainingWordIds) == Set(setup.words.map(\.id)))
        #expect(state.scores.isEmpty)
    }

    @Test("Starting again is ignored once the game is underway")
    mutating func startIsIdempotent() {
        let started = Fixtures.started()

        #expect(GameRules.start(started, startingTeamIndex: 1, using: &generator) == started)
    }

    @Test("A game with an empty hat cannot start")
    mutating func startRequiresWords() {
        let setup = Fixtures.state(words: [])

        #expect(GameRules.start(setup, startingTeamIndex: 0, using: &generator).phase == .setup)
    }

    @Test("A game needs two teams of at least two players and a running clock")
    mutating func startRequiresPlayableTeams() {
        let lonelyTeam = Fixtures.state(teams: Fixtures.teams(count: 1))
        let soloPlayers = Fixtures.state(teams: Fixtures.teams(playersPerTeam: 1))
        let noClock = Fixtures.state(roundDuration: 0)

        #expect(GameRules.start(lonelyTeam, startingTeamIndex: 0, using: &generator).phase == .setup)
        #expect(GameRules.start(soloPlayers, startingTeamIndex: 0, using: &generator).phase == .setup)
        #expect(GameRules.start(noClock, startingTeamIndex: 0, using: &generator).phase == .setup)
    }

    @Test("A saved game without a clock, a player, or a word to go on is not playable")
    func consistencyRejectsStuckStates() {
        var noClock = Fixtures.started()
        noClock.settings.roundDuration = 0
        var emptyTeam = Fixtures.started()
        emptyTeam.teams[1].players = []
        var timedOutWithEmptyHat = GameRules.expire(Fixtures.playing())
        timedOutWithEmptyHat.remainingWordIds = []

        #expect(Fixtures.started().isConsistent)
        #expect(!noClock.isConsistent)
        #expect(!emptyTeam.isConsistent)
        #expect(!timedOutWithEmptyHat.isConsistent)
    }

    @Test("An out-of-range starting index falls back to the first team")
    mutating func startClampsTeamIndex() {
        let setup = Fixtures.state()

        let state = GameRules.start(setup, startingTeamIndex: 9, using: &generator)

        #expect(state.currentTeamId == setup.teams[0].id)
    }

    // MARK: - Beginning a turn
    @Test("A team's first turn uses the chosen explainer and locks its roles")
    mutating func firstTurnLocksExplainer() throws {
        let started = Fixtures.started()
        let team = try #require(started.currentTeam)

        let state = GameRules.beginTurn(started, explainerIndex: 1, using: &generator)

        #expect(state.phase == .playing)
        #expect(state.explainerIndex(for: team) == 1)
        #expect(!state.canSelectExplainer(for: team))
        #expect(state.turn?.remaining == .seconds(60))
        #expect(state.currentWordId.map(state.remainingWordIds.contains) == true)
    }

    @Test("An invalid explainer index picks the first player")
    mutating func invalidExplainerIndexDefaultsToFirst() throws {
        let started = Fixtures.started()
        let team = try #require(started.currentTeam)

        let state = GameRules.beginTurn(started, explainerIndex: 7, using: &generator)

        #expect(state.explainerIndex(for: team) == 0)
    }

    @Test("Beginning a turn twice is ignored")
    mutating func beginTurnIsIdempotent() {
        let playing = Fixtures.playing()

        #expect(GameRules.beginTurn(playing, explainerIndex: 1, using: &generator) == playing)
    }

    @Test("A locked team ignores a hand-picked explainer")
    mutating func lockedTeamIgnoresExplainerChoice() throws {
        var state = Fixtures.started(teams: Fixtures.teams(count: 2, playersPerTeam: 3))
        let team = try #require(state.currentTeam)
        // The team plays, then the other team, so it is up again with roles locked.
        for _ in 0..<2 {
            state = GameRules.beginTurn(state, explainerIndex: 0, using: &generator)
            state = GameRules.continueAfterTurn(GameRules.expire(state))
        }
        #expect(state.currentTeamId == team.id)

        state = GameRules.beginTurn(state, explainerIndex: 0, using: &generator)

        #expect(state.explainerIndex(for: team) == 1)
    }

    // MARK: - Guessing and skipping
    @Test("A guess scores the word and draws the next one")
    mutating func guessScoresWord() throws {
        let playing = Fixtures.playing()
        let team = try #require(playing.currentTeam)
        let word = try #require(playing.currentWordId)

        let state = GameRules.guess(playing, remaining: .seconds(50), using: &generator)

        #expect(state.scores[.first]?[team.id] == [word])
        #expect(!state.remainingWordIds.contains(word))
        #expect(state.turn?.guessedWordIds == [word])
        #expect(state.currentWordId != nil)
        #expect(state.currentWordId != word)
    }

    @Test("Guesses are ignored while paused or with no time left")
    mutating func guessNeedsRunningClock() {
        let playing = Fixtures.playing()
        let paused = GameRules.pause(playing, remaining: .seconds(40))

        #expect(GameRules.guess(paused, remaining: .seconds(40), using: &generator) == paused)
        #expect(GameRules.guess(playing, remaining: .zero, using: &generator) == playing)
    }

    @Test("Emptying the hat ends the turn and the round, keeping leftover time")
    mutating func emptyingHatEndsTurn() throws {
        let playing = Fixtures.playing()
        let team = try #require(playing.currentTeam)

        let state = playing.guessingAll(remaining: .milliseconds(41_200))

        #expect(state.phase == .turnResults)
        #expect(state.turn?.endReason == .allWordsGuessed)
        #expect(state.remainingWordIds.isEmpty)
        #expect(state.currentWordId == nil)
        #expect(state.carryOverSeconds[team.id] == 42)
    }

    @Test("Skipping swaps in a different word and keeps the old one in the hat")
    mutating func skipSwapsWord() throws {
        let playing = Fixtures.playing()
        let word = try #require(playing.currentWordId)

        let state = GameRules.skip(playing, using: &generator)

        #expect(state.currentWordId != word)
        #expect(state.remainingWordIds.contains(word))
        #expect(state.scores.isEmpty)
    }

    @Test("Skipping is unavailable when disabled, paused, or on the last word")
    mutating func skipGuards() {
        let disabled = Fixtures.playing(isSkippingEnabled: false)
        let lastWord = Fixtures.playing(words: Fixtures.words(["solo"]))
        let paused = GameRules.pause(Fixtures.playing(), remaining: .seconds(10))

        #expect(GameRules.skip(disabled, using: &generator) == disabled)
        #expect(GameRules.skip(lastWord, using: &generator) == lastWord)
        #expect(GameRules.skip(paused, using: &generator) == paused)
        #expect(!GameRules.canSkip(disabled))
        #expect(GameRules.canSkip(Fixtures.playing()))
    }

    // MARK: - Pausing and ending
    @Test("Pause records the remaining time; resume clears the flag")
    func pauseAndResume() {
        let playing = Fixtures.playing()

        let paused = GameRules.pause(playing, remaining: .seconds(33))
        let resumed = GameRules.resume(paused)

        #expect(paused.turn?.isPaused == true)
        #expect(paused.turn?.remaining == .seconds(33))
        #expect(GameRules.pause(paused, remaining: .seconds(1)) == paused)
        #expect(resumed.turn?.isPaused == false)
        #expect(GameRules.resume(resumed) == resumed)
    }

    @Test("Snapshot updates only the remaining time, and only mid-turn")
    func snapshotRecordsTime() {
        let playing = Fixtures.playing()
        let started = Fixtures.started()

        #expect(GameRules.snapshot(playing, remaining: .seconds(12)).turn?.remaining == .seconds(12))
        #expect(GameRules.snapshot(started, remaining: .seconds(12)) == started)
    }

    @Test("Expiry ends the turn once; words stay in the hat")
    func expireEndsTurnOnce() {
        let playing = Fixtures.playing()

        let expired = GameRules.expire(playing)

        #expect(expired.phase == .turnResults)
        #expect(expired.turn?.endReason == .timeExpired)
        #expect(expired.remainingWordIds.count == playing.remainingWordIds.count)
        #expect(GameRules.expire(expired) == expired)
        #expect(GameRules.giveUp(expired, remaining: .seconds(5)) == expired)
    }

    @Test("Giving up works even while paused and is recorded as such")
    func giveUpWhilePaused() {
        let paused = GameRules.pause(Fixtures.playing(), remaining: .seconds(20))

        let state = GameRules.giveUp(paused, remaining: .seconds(20))

        #expect(state.phase == .turnResults)
        #expect(state.turn?.endReason == .gaveUp)
        #expect(state.turn?.isPaused == false)
    }

    // MARK: - Continuing
    @Test("After a timed-out turn the next team is up and the explainer rotated")
    func continueAfterTimeoutRotates() throws {
        let playing = Fixtures.playing()
        let team = try #require(playing.currentTeam)

        let state = GameRules.continueAfterTurn(GameRules.expire(playing))

        #expect(state.phase == .nextTeam)
        #expect(state.currentTeamId == playing.teams[1].id)
        #expect(state.explainerIndex(for: team) == 1)
        #expect(state.turn == nil)
        #expect(state.round == .first)
    }

    @Test("Continuing twice never skips a team or rotates twice")
    func continueIsIdempotent() {
        let once = GameRules.continueAfterTurn(GameRules.expire(Fixtures.playing()))

        #expect(GameRules.continueAfterTurn(once) == once)
    }

    @Test("Teams rotate in order and wrap around")
    mutating func teamsRotateInOrder() {
        var state = Fixtures.started(teams: Fixtures.teams(count: 3))
        var order: [Team.ID?] = []
        for _ in 0..<4 {
            order.append(state.currentTeamId)
            state = GameRules.beginTurn(state, explainerIndex: 0, using: &generator)
            state = GameRules.continueAfterTurn(GameRules.expire(state))
        }

        #expect(order == [state.teams[0].id, state.teams[1].id, state.teams[2].id, state.teams[0].id])
    }

    @Test("The team that empties the hat starts the next round with its explainer and leftover time")
    mutating func emptyingHatCarriesOver() throws {
        var state = Fixtures.playing()
        let team = try #require(state.currentTeam)
        let explainer = state.explainerIndex(for: team)

        state = GameRules.continueAfterTurn(state.guessingAll(remaining: .seconds(17)))

        #expect(state.phase == .nextTeam)
        #expect(state.round == .second)
        #expect(state.currentTeamId == team.id)
        #expect(state.explainerIndex(for: team) == explainer)
        #expect(Set(state.remainingWordIds) == Set(state.words.map(\.id)))

        state = GameRules.beginTurn(state, explainerIndex: nil, using: &generator)

        #expect(state.turn?.remaining == .seconds(17))
        #expect(state.carryOverSeconds.isEmpty)
    }

    @Test("Other teams lose any carry-over at the round boundary")
    func roundBoundaryResetsOtherTeams() throws {
        var state = Fixtures.playing()
        let team = try #require(state.currentTeam)
        let other = state.teams[1].id
        state.carryOverSeconds[other] = 12

        state = GameRules.continueAfterTurn(state.guessingAll(remaining: .seconds(5)))

        #expect(state.carryOverSeconds == [team.id: 5])
    }

    @Test("After round three the game is finished with no carry-over")
    func thirdRoundFinishes() {
        let state = Fixtures.started().clearingRound().clearingRound().clearingRound()

        #expect(state.phase == .finished)
        #expect(state.isFinished)
        #expect(state.carryOverSeconds.isEmpty)
        #expect(state.startedRounds == GameRound.allCases)
        #expect(GameRules.continueAfterTurn(state) == state)
    }

    // MARK: - Rematch and new words
    @Test("Rematch keeps teams and words but clears every score")
    func rematchResets() {
        let finished = Fixtures.started().clearingRound().clearingRound().clearingRound()

        let state = GameRules.rematch(finished)

        #expect(state.phase == .setup)
        #expect(state.scores.isEmpty)
        #expect(state.teams == finished.teams)
        #expect(state.words == finished.words)
        #expect(state.lockedTeamIds.isEmpty)
        #expect(state.explainerIndices.isEmpty)
        #expect(state.startedRounds.isEmpty)
    }

    @Test("New words keeps teams and empties the hat")
    func newWordsEmptiesHat() {
        let state = GameRules.newWords(Fixtures.finished())

        #expect(state.phase == .setup)
        #expect(state.words.isEmpty)
        #expect(state.teams.count == 2)
    }

    @Test("Abandoning a game in progress clears its progress; other phases are untouched")
    func abandonResetsOnlyGamesInProgress() {
        let abandoned = GameRules.abandon(Fixtures.playing())

        #expect(abandoned.phase == .setup)
        #expect(!abandoned.scoreboard.hasAnyScore)
        #expect(abandoned.turn == nil)
        let finished = Fixtures.finished()
        let setup = Fixtures.state()
        #expect(GameRules.abandon(finished) == finished)
        #expect(GameRules.abandon(setup) == setup)
    }

    @Test("Rematch and new words are ignored while a game is in progress")
    func rematchAndNewWordsIgnoredMidGame() {
        for state in [Fixtures.started(), Fixtures.playing()] {
            #expect(GameRules.rematch(state) == state)
            #expect(GameRules.newWords(state) == state)
        }
    }

    // MARK: - Carry-over rounding
    @Test(
        "Carry-over is the countdown's displayed value, at least one second",
        arguments: [
            (Duration.milliseconds(1), 1),
            (.milliseconds(200), 1),
            (.seconds(1), 1),
            (.milliseconds(1_500), 2),
            (.seconds(42), 42),
        ]
    )
    func carryOverRoundsUp(remaining: Duration, expected: Int) {
        #expect(GameRules.carryOverSeconds(for: remaining) == expected)
    }
}
