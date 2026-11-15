//
//  Timeout.swift
//  Networking
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
import Synchronization

/// Runs `operation`, throwing `NetworkingError.timeout` if it has not
/// finished within `duration`, or `CancellationError` if the caller is
/// cancelled first.
///
/// Firebase completion handlers ignore task cancellation, so a task group
/// cannot express this: the group waits for its hung child before returning.
/// Here the caller resumes on whichever finishes first and the loser is left
/// to complete — or not — on its own.
func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let race = TimeoutRace<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            guard race.install(continuation) else { return }
            let work = Task {
                do {
                    race.finish(.success(try await operation()))
                } catch {
                    race.finish(.failure(error))
                }
            }
            let timer = Task {
                try? await Task.sleep(for: duration)
                race.finish(.failure(NetworkingError.timeout))
            }
            race.onFinish {
                work.cancel()
                timer.cancel()
            }
        }
    } onCancel: {
        race.finish(.failure(CancellationError()))
    }
}

/// Resume-once guard shared by the operation, the timer, and cancellation.
private final class TimeoutRace<T: Sendable>: Sendable {
    typealias Cleanup = @Sendable () -> Void

    private struct State: ~Copyable {
        var continuation: CheckedContinuation<T, Error>?
        var earlyResult: Result<T, Error>?
        var cleanup: Cleanup?
        var isFinished = false
    }

    private let state = Mutex(State())

    /// Stores the continuation, or resumes it at once if cancellation already
    /// won. Returns `false` when there is nothing left to start.
    func install(_ continuation: CheckedContinuation<T, Error>) -> Bool {
        let early = state.withLock { state -> Result<T, Error>? in
            if let result = state.earlyResult { return result }
            state.continuation = continuation
            return nil
        }
        guard let early else { return true }
        continuation.resume(with: early)
        return false
    }

    func finish(_ result: Result<T, Error>) {
        let (continuation, cleanup) = state.withLock { state -> (CheckedContinuation<T, Error>?, Cleanup?) in
            guard !state.isFinished else { return (nil, nil) }
            state.isFinished = true
            if state.continuation == nil {
                state.earlyResult = result
            }
            defer {
                state.continuation = nil
                state.cleanup = nil
            }
            return (state.continuation, state.cleanup)
        }
        continuation?.resume(with: result)
        cleanup?()
    }

    func onFinish(_ cleanup: @escaping Cleanup) {
        let isFinished = state.withLock { state -> Bool in
            if !state.isFinished { state.cleanup = cleanup }
            return state.isFinished
        }
        if isFinished { cleanup() }
    }
}
