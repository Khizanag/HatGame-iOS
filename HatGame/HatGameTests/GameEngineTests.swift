//
//  GameEngineTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

@testable import HatGame
import Testing

@MainActor
@Suite("Game engine", .timeLimit(.minutes(1)))
struct GameEngineTests {
    private let clock = ManualClock()
    private let store = RecordingGameStore()
    private let sound = SoundSpy()

    // MARK: - Clock
    @Test("A turn publishes its countdown second by second")
    func tickPublishesRemainingSeconds() async {
        let engine = makeEngine(roundDuration: 10)
        engine.beginTurn(explainerIndex: 0)
        #expect(engine.remainingSeconds == 10)

        await advance(seconds: 3)

        #expect(engine.remainingSeconds == 7)
        #expect(engine.phase == .playing)
    }

    @Test("The turn expires exactly at its duration and the sound plays once")
    func expiryPlaysSoundOnce() async {
        let engine = makeEngine(roundDuration: 5)
        engine.beginTurn(explainerIndex: 0)

        await advance(seconds: 4)
        #expect(engine.phase == .playing)
        #expect(engine.remainingSeconds == 1)

        await advance(seconds: 1)
        #expect(engine.phase == .turnResults)
        #expect(engine.state.turn?.endReason == .timeExpired)
        #expect(engine.remainingSeconds == 0)

        await advance(seconds: 5)
        engine.giveUp()
        #expect(sound.timeUpCount == 1)
    }

    @Test("A paused clock does not run down")
    func pauseStopsClock() async {
        let engine = makeEngine(roundDuration: 10)
        engine.beginTurn(explainerIndex: 0)
        await advance(seconds: 2)

        engine.togglePause()
        await advance(seconds: 30)
        #expect(engine.isPaused)
        #expect(engine.remainingSeconds == 8)
        #expect(engine.phase == .playing)

        engine.togglePause()
        await advance(seconds: 3)
        #expect(!engine.isPaused)
        #expect(engine.remainingSeconds == 5)
    }

    @Test("A guess landing at expiry ends the turn instead of scoring")
    func guessAtExpiryDoesNotScore() async {
        let engine = makeEngine(roundDuration: 5)
        engine.beginTurn(explainerIndex: 0)
        await settle()

        await clock.advance(by: .seconds(5), settling: false)
        engine.guess()

        #expect(engine.phase == .turnResults)
        #expect(engine.state.turn?.endReason == .timeExpired)
        #expect(engine.state.scores.isEmpty)
        #expect(sound.timeUpCount == 1)
    }

    @Test("Emptying the hat carries the displayed leftover time into the next round")
    func carryOverThroughEngine() async throws {
        let engine = makeEngine(roundDuration: 60)
        engine.beginTurn(explainerIndex: 0)
        await settle()
        await clock.advance(by: .milliseconds(17_400))

        while engine.phase == .playing {
            engine.guess()
        }
        engine.continueAfterTurn()
        engine.beginTurn()

        #expect(engine.state.round == .second)
        #expect(engine.remainingSeconds == 43)
    }

    // MARK: - Lifecycle
    @Test("Leaving the foreground pauses a running turn and saves its remaining time")
    func backgroundAutoPauses() async {
        let engine = makeEngine(roundDuration: 30)
        engine.beginTurn(explainerIndex: 0)
        await advance(seconds: 4)

        engine.handleLeavingForeground()
        await engine.waitForPendingWrites()

        #expect(engine.isPaused)
        #expect(await store.lastSaved?.turn?.isPaused == true)
        #expect(await store.lastSaved?.turn?.remaining == .seconds(26))
    }

    @Test("Leaving the foreground outside a turn just saves")
    func backgroundOutsideTurnSaves() async {
        let engine = makeEngine()
        engine.handleLeavingForeground()
        await engine.waitForPendingWrites()

        #expect(await store.saveCount == 2)
        #expect(!engine.isPaused)
    }

    @Test("Every transition saves; ignored intents do not")
    func everyTransitionSaves() async {
        let engine = makeEngine(teams: Fixtures.teams(count: 2), words: Fixtures.words(["a", "b", "c", "d"]))
        engine.beginTurn(explainerIndex: 0)
        engine.beginTurn(explainerIndex: 1)
        engine.skip()
        engine.guess()
        engine.pause()
        engine.pause()
        engine.resume()
        engine.giveUp()
        engine.continueAfterTurn()
        engine.continueAfterTurn()
        await engine.waitForPendingWrites()

        // start + beginTurn + skip + guess + pause + resume + giveUp + continue
        #expect(await store.saveCount == 8)
        #expect(await store.lastSaved == engine.state)
    }

    @Test("Finishing clears the saved game, and so does a rematch")
    func finishingClearsSave() async {
        let engine = makeEngine(words: Fixtures.words(["solo"]))
        playToEnd(engine)
        await engine.waitForPendingWrites()
        #expect(engine.phase == .finished)
        #expect(await store.clearCount == 1)
        #expect(await store.load() == nil)

        engine.rematch()
        await engine.waitForPendingWrites()
        #expect(engine.phase == .setup)
        #expect(engine.scoreboard.hasAnyScore == false)
        #expect(await store.clearCount == 2)
    }

    @Test("New words empties the engine's hat")
    func newWordsEmptiesHat() async {
        let engine = makeEngine(words: Fixtures.words(["solo"]))
        engine.newWords()
        #expect(engine.phase == .nextTeam)

        playToEnd(engine)
        engine.newWords()

        #expect(engine.phase == .setup)
        #expect(engine.state.words.isEmpty)
    }

    @Test("Pausing after the clock hit zero ends the turn instead")
    func pauseAtZeroExpires() async {
        let engine = makeEngine(roundDuration: 3)
        engine.beginTurn(explainerIndex: 0)
        // Move the clock past zero without letting the tick loop run.
        await clock.advance(by: .seconds(3))

        engine.pause()

        #expect(engine.phase == .turnResults)
        #expect(engine.state.turn?.endReason == .timeExpired)
        #expect(sound.timeUpCount == 1)
    }

    @Test("Giving up after the clock hit zero counts as time running out")
    func giveUpAtZeroExpires() async {
        let engine = makeEngine(roundDuration: 3)
        engine.beginTurn(explainerIndex: 0)
        await clock.advance(by: .seconds(3))

        engine.giveUp()

        #expect(engine.state.turn?.endReason == .timeExpired)
    }

    @Test("A turn saved with no time left comes back already over")
    func restoreAtZeroIsExpired() {
        var saved = Fixtures.playing(roundDuration: 60)
        saved.turn?.remaining = .zero

        let engine = GameEngine(state: saved, clock: clock, generator: SeededGenerator(), store: store, sound: sound)

        #expect(engine.phase == .turnResults)
        #expect(engine.state.turn?.endReason == .timeExpired)
    }

    @Test("A running turn is saved every five seconds")
    func runningTurnIsSnapshotted() async {
        let engine = makeEngine(roundDuration: 30)
        engine.beginTurn(explainerIndex: 0)
        await engine.waitForPendingWrites()
        let savesBefore = await store.saveCount

        await advance(seconds: 10)
        await engine.waitForPendingWrites()

        #expect(await store.saveCount == savesBefore + 2)
        #expect(await store.lastSaved?.turn?.remaining == .seconds(20))
    }

    @Test("Starting is ignored once a game is underway")
    func startIsIdempotent() {
        let engine = makeEngine()
        let state = engine.state

        engine.start(Fixtures.state(), startingTeamIndex: 1)

        #expect(engine.state == state)
    }

    @Test("A game saved mid-turn comes back paused with its remaining time")
    func restoreComesBackPaused() async {
        var saved = Fixtures.playing(roundDuration: 60)
        saved.turn?.remaining = .seconds(30)

        let engine = GameEngine(state: saved, clock: clock, generator: SeededGenerator(), store: store, sound: sound)

        #expect(engine.isPaused)
        #expect(engine.remainingSeconds == 30)

        engine.resume()
        await advance(seconds: 2)
        #expect(engine.remainingSeconds == 28)
    }

    @Test("Scene handling, skip, and derived state forward to the rules")
    func derivedState() {
        let engine = makeEngine()
        #expect(!engine.canSkip)
        engine.beginTurn(explainerIndex: 0)
        #expect(engine.canSkip)
        #expect(engine.phase == .playing)
        #expect(!engine.scoreboard.hasAnyScore)
    }
}

// MARK: - Helpers
private extension GameEngineTests {
    /// An engine already started (at Next Team) on the manual clock.
    func makeEngine(
        teams: [Team] = Fixtures.teams(),
        words: [Word] = Fixtures.words(),
        roundDuration: Int = 60
    ) -> GameEngine {
        let setup = Fixtures.state(teams: teams, words: words, roundDuration: roundDuration)
        let engine = GameEngine(state: setup, clock: clock, generator: SeededGenerator(), store: store, sound: sound)
        engine.start(setup, startingTeamIndex: 0)
        return engine
    }

    /// Plays every round to the end: the up team empties the hat each time.
    func playToEnd(_ engine: GameEngine) {
        while engine.phase != .finished {
            engine.beginTurn(explainerIndex: 0)
            while engine.phase == .playing {
                engine.guess()
            }
            engine.continueAfterTurn()
        }
    }

    /// Advances one second at a time so the tick loop observes each boundary.
    func advance(seconds: Int) async {
        for _ in 0..<seconds {
            await settle()
            await clock.advance(by: .seconds(1))
        }
    }
}
