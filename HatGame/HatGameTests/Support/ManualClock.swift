//
//  ManualClock.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// A `Clock` that only moves when a test advances it. Sleepers whose
/// deadline is reached are resumed; cancelled sleepers throw.
final class ManualClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        let id: UUID
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [Sleeper] = []

    var now: Instant { lock.withLock { current } }
    var minimumResolution: Duration { .zero }
    var sleeperCount: Int { lock.withLock { sleepers.count } }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                let isDue = lock.withLock {
                    guard deadline > current else { return true }
                    sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                    return false
                }
                if isDue {
                    continuation.resume()
                }
            }
        } onCancel: {
            let sleeper = lock.withLock { () -> Sleeper? in
                guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return nil }
                return sleepers.remove(at: index)
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves time forward, wakes every due sleeper, then (by default) yields so
    /// woken main-actor work runs before the caller continues.
    func advance(by duration: Duration, settling: Bool = true) async {
        let due = lock.withLock { () -> [Sleeper] in
            current = current.advanced(by: duration)
            let due = sleepers.filter { $0.deadline <= current }
            sleepers.removeAll { $0.deadline <= current }
            return due
        }
        due.forEach { $0.continuation.resume() }
        if settling {
            await settle()
        }
    }
}

/// Yields repeatedly so queued tasks (the engine's tick loop, saves) get to run.
func settle() async {
    for _ in 0..<50 {
        await Task.yield()
    }
}
