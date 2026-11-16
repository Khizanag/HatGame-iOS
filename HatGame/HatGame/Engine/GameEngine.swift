//
//  GameEngine.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Observation

/// Runs a single-device game: owns its `GameState`, the turn clock, and
/// persistence. Views render `state` and call the intent methods; every rule
/// lives in `GameRules`.
///
/// Time comes from an injected `Clock` and randomness from an injected
/// generator, so tests can drive a whole game deterministically.
@MainActor
@Observable
final class GameEngine {
    private(set) var state: GameState
    /// The countdown shown for the turn in progress, in whole seconds (rounded up).
    private(set) var remainingSeconds: Int

    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private let now: @Sendable () -> Duration
    @ObservationIgnored private var generator: any RandomNumberGenerator
    @ObservationIgnored private let store: any GameStore
    @ObservationIgnored private let sound: any SoundPlaying
    @ObservationIgnored private var turnClock: TurnClock?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var persistTask: Task<Void, Never>?

    /// Seconds of countdown between snapshots of a running turn.
    private static let snapshotInterval = 5

    /// - Parameter state: A fresh `.setup` state, or a saved game. A saved game
    ///   that was mid-turn comes back paused with its remaining time.
    init(
        state: GameState,
        clock: any Clock<Duration> = ContinuousClock(),
        generator: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        store: any GameStore,
        sound: any SoundPlaying
    ) {
        var restored = GameRules.pause(state, remaining: state.turn?.remaining ?? .zero)
        if restored.phase == .playing, (restored.turn?.remaining ?? .zero) <= .zero {
            restored = GameRules.expire(restored)
        }
        self.state = restored
        self.clock = clock
        self.now = Self.makeTimeline(for: clock)
        self.generator = generator
        self.store = store
        self.sound = sound
        let remaining = restored.turn?.remaining ?? .seconds(restored.settings.roundDuration)
        remainingSeconds = TurnClock.displayedSeconds(for: remaining)
        if restored.phase == .playing {
            turnClock = TurnClock(remaining: remaining)
        }
    }
}

// MARK: - Derived state
extension GameEngine {
    var phase: GameState.Phase { state.phase }
    var isPaused: Bool { state.phase == .playing && state.turn?.isPaused == true }
    var canSkip: Bool { GameRules.canSkip(state) }
    var scoreboard: Scoreboard { state.scoreboard }
}

// MARK: - Intents
extension GameEngine {
    /// Starts a game built from setup. Ignored unless the engine is in `.setup`.
    func start(_ setup: GameState, startingTeamIndex: Int) {
        guard state.phase == .setup else { return }
        apply(GameRules.start(setup, startingTeamIndex: startingTeamIndex, using: &generator))
    }

    func beginTurn(explainerIndex: Int? = nil) {
        apply(GameRules.beginTurn(state, explainerIndex: explainerIndex, using: &generator))
    }

    func guess() {
        guard state.phase == .playing else { return }
        let remaining = liveRemaining()
        guard remaining > .zero else {
            expire()
            return
        }
        apply(GameRules.guess(state, remaining: remaining, using: &generator))
    }

    func skip() {
        apply(GameRules.skip(state, using: &generator))
    }

    func pause() {
        if expireIfTimeIsUp() { return }
        apply(GameRules.pause(state, remaining: liveRemaining()))
    }

    func resume() {
        apply(GameRules.resume(state))
    }

    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    func giveUp() {
        if expireIfTimeIsUp() { return }
        apply(GameRules.giveUp(state, remaining: liveRemaining()))
    }

    func continueAfterTurn() {
        apply(GameRules.continueAfterTurn(state))
    }

    func rematch() {
        apply(GameRules.rematch(state))
    }

    func newWords() {
        apply(GameRules.newWords(state))
    }

    /// Ends a game in progress for good; the saved game is cleared.
    func abandon() {
        apply(GameRules.abandon(state))
    }

    /// The app left the foreground: a running turn pauses so the clock can't
    /// run down unseen, and the latest state is saved.
    func handleLeavingForeground() {
        if state.phase == .playing, !isPaused {
            pause()
        } else {
            persist()
        }
    }

    /// Resolves once every save or clear issued so far has finished.
    func waitForPendingWrites() async {
        await persistTask?.value
    }
}

// MARK: - Transitions
private extension GameEngine {
    func apply(_ next: GameState) {
        guard next != state else { return }
        let previous = state
        state = next
        syncClock(after: previous)
        persist()
    }

    func expire() {
        guard state.phase == .playing else { return }
        apply(GameRules.expire(state))
        remainingSeconds = 0
        sound.playTimeUp()
    }

    /// A tap that lands after the clock hit zero but before the tick ran is
    /// treated as the time running out, so the turn never sits paused at zero.
    func expireIfTimeIsUp() -> Bool {
        guard state.phase == .playing, state.turn?.isPaused == false, liveRemaining() <= .zero else {
            return false
        }
        expire()
        return true
    }

    func liveRemaining() -> Duration {
        turnClock?.remaining(at: now()) ?? state.turn?.remaining ?? .zero
    }

    /// Saves an in-progress game, or clears the save once there is nothing to resume.
    func persist() {
        var snapshot = state
        if let turnClock {
            snapshot = GameRules.snapshot(snapshot, remaining: turnClock.remaining(at: now()))
        }
        let store = store
        let previous = persistTask
        persistTask = Task {
            await previous?.value
            if snapshot.phase.isInProgress {
                await store.save(snapshot)
            } else {
                await store.clear()
            }
        }
    }
}

// MARK: - Clock
private extension GameEngine {
    func syncClock(after previous: GameState) {
        guard state.phase == .playing, let turn = state.turn else {
            stopTicking()
            turnClock = nil
            return
        }
        let current = now()
        if previous.phase != .playing || turnClock == nil {
            turnClock = TurnClock(remaining: turn.remaining)
        }
        let wasRunning = previous.phase == .playing && previous.turn?.isPaused == false
        if turn.isPaused {
            turnClock?.pause(at: current)
            stopTicking()
        } else {
            turnClock?.resume(at: current)
            if !wasRunning {
                startTicking()
            }
        }
        remainingSeconds = turnClock?.displayedSeconds(at: current) ?? 0
    }

    func tick() {
        guard state.phase == .playing, let turnClock, turnClock.isRunning else { return }
        let current = now()
        if turnClock.isExpired(at: current) {
            expire()
        } else {
            remainingSeconds = turnClock.displayedSeconds(at: current)
            // Transitions already save; this bounds what a crash mid-turn loses.
            if remainingSeconds.isMultiple(of: Self.snapshotInterval) {
                persist()
            }
        }
    }

    func delayUntilNextTick() -> Duration? {
        guard let turnClock, turnClock.isRunning else { return nil }
        let current = now()
        return turnClock.isExpired(at: current) ? .zero : turnClock.timeUntilNextTick(at: current)
    }

    func startTicking() {
        tickTask?.cancel()
        let clock = clock
        tickTask = Task { [weak self] in
            while let delay = self?.delayUntilNextTick() {
                do {
                    try await Self.sleep(on: clock, for: delay)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    nonisolated static func sleep<C: Clock<Duration>>(on clock: C, for duration: Duration) async throws {
        try await clock.sleep(until: clock.now.advanced(by: duration), tolerance: nil)
    }

    /// Elapsed time since the engine was created, read from `clock`.
    nonisolated static func makeTimeline<C: Clock<Duration>>(for clock: C) -> @Sendable () -> Duration {
        let origin = clock.now
        return { origin.duration(to: clock.now) }
    }
}
