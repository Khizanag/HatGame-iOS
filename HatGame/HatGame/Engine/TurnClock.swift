//
//  TurnClock.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

/// A pausable countdown computed from timestamps rather than counted ticks,
/// so it never drifts and expires exactly when its time is used up.
///
/// Timestamps are `Duration`s on one monotonic timeline (the engine measures
/// them from its clock), which keeps the type independent of any `Clock`.
nonisolated struct TurnClock: Sendable, Equatable {
    /// Time left when the clock last stopped (or was created).
    private(set) var banked: Duration
    /// When the clock last started running; `nil` while stopped.
    private(set) var resumedAt: Duration?

    init(remaining: Duration) {
        banked = max(remaining, .zero)
    }

    var isRunning: Bool { resumedAt != nil }

    func remaining(at now: Duration) -> Duration {
        guard let resumedAt else { return banked }
        return max(banked - (now - resumedAt), .zero)
    }

    func isExpired(at now: Duration) -> Bool {
        remaining(at: now) <= .zero
    }

    /// The countdown's display value: remaining time rounded up, so a fresh
    /// 60 s turn shows 60 and the display reaches 0 only at expiry.
    func displayedSeconds(at now: Duration) -> Int {
        Self.displayedSeconds(for: remaining(at: now))
    }

    /// How long until the displayed value next changes (or the clock expires);
    /// `nil` while stopped or once expired.
    func timeUntilNextTick(at now: Duration) -> Duration? {
        guard isRunning else { return nil }
        let left = remaining(at: now)
        guard left > .zero else { return nil }
        return left - .seconds(Self.displayedSeconds(for: left) - 1)
    }

    mutating func resume(at now: Duration) {
        guard resumedAt == nil else { return }
        resumedAt = now
    }

    mutating func pause(at now: Duration) {
        guard resumedAt != nil else { return }
        banked = remaining(at: now)
        resumedAt = nil
    }

    /// Whole seconds shown for `remaining`, rounded up. Exact integer math —
    /// no floating-point edge at whole-second boundaries.
    static func displayedSeconds(for remaining: Duration) -> Int {
        guard remaining > .zero else { return 0 }
        let (seconds, attoseconds) = remaining.components
        return Int(seconds) + (attoseconds > 0 ? 1 : 0)
    }
}
