//
//  TurnClockTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

@testable import HatGame
import Testing

@Suite("Turn clock")
struct TurnClockTests {
    @Test("A new clock is stopped and shows its full time")
    func startsStopped() {
        let clock = TurnClock(remaining: .seconds(60))

        #expect(!clock.isRunning)
        #expect(clock.displayedSeconds(at: .seconds(100)) == 60)
        #expect(clock.timeUntilNextTick(at: .zero) == nil)
    }

    @Test("Running time is measured from timestamps, not counted ticks")
    func measuresElapsedTime() {
        var clock = TurnClock(remaining: .seconds(60))
        clock.resume(at: .seconds(10))

        #expect(clock.remaining(at: .milliseconds(12_500)) == .milliseconds(57_500))
        #expect(clock.displayedSeconds(at: .milliseconds(12_500)) == 58)
    }

    @Test("Expires exactly at its duration and never shows 0 before that")
    func expiresExactly() {
        var clock = TurnClock(remaining: .seconds(60))
        clock.resume(at: .zero)

        #expect(clock.displayedSeconds(at: .milliseconds(59_999)) == 1)
        #expect(!clock.isExpired(at: .milliseconds(59_999)))
        #expect(clock.isExpired(at: .seconds(60)))
        #expect(clock.displayedSeconds(at: .seconds(60)) == 0)
        #expect(clock.remaining(at: .seconds(90)) == .zero)
    }

    @Test("Pausing banks the remaining time until resumed")
    func pauseBanksTime() {
        var clock = TurnClock(remaining: .seconds(30))
        clock.resume(at: .zero)
        clock.pause(at: .seconds(10))

        #expect(clock.remaining(at: .seconds(500)) == .seconds(20))

        clock.resume(at: .seconds(500))

        #expect(clock.remaining(at: .seconds(505)) == .seconds(15))
    }

    @Test("Repeated resume or pause calls are no-ops")
    func repeatedCallsAreIgnored() {
        var clock = TurnClock(remaining: .seconds(30))
        clock.resume(at: .zero)
        clock.resume(at: .seconds(10))
        #expect(clock.remaining(at: .seconds(10)) == .seconds(20))

        clock.pause(at: .seconds(10))
        clock.pause(at: .seconds(20))
        #expect(clock.remaining(at: .seconds(20)) == .seconds(20))
    }

    @Test("The next tick lands where the displayed second changes")
    func nextTickAlignsWithDisplay() {
        var clock = TurnClock(remaining: .seconds(60))
        clock.resume(at: .zero)

        #expect(clock.timeUntilNextTick(at: .zero) == .seconds(1))
        #expect(clock.timeUntilNextTick(at: .milliseconds(300)) == .milliseconds(700))
        #expect(clock.timeUntilNextTick(at: .milliseconds(59_600)) == .milliseconds(400))
        #expect(clock.timeUntilNextTick(at: .seconds(60)) == nil)
    }

    @Test("Negative starting time is clamped to zero")
    func clampsNegative() {
        #expect(TurnClock(remaining: .seconds(-5)).remaining(at: .zero) == .zero)
    }

    @Test(
        "Displayed seconds round up",
        arguments: [
            (Duration.zero, 0),
            (.seconds(-1), 0),
            (.nanoseconds(1), 1),
            (.seconds(1), 1),
            (.milliseconds(1_001), 2),
            (.seconds(60), 60),
        ]
    )
    func displayedSecondsRoundUp(remaining: Duration, expected: Int) {
        #expect(TurnClock.displayedSeconds(for: remaining) == expected)
    }
}
