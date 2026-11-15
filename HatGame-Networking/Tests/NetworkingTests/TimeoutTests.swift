//
//  TimeoutTests.swift
//  NetworkingTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import Networking
import Testing

@Suite("withTimeout")
struct TimeoutTests {
    @Test("A fast operation returns its value")
    func fastOperationReturns() async throws {
        let value = try await withTimeout(.seconds(5)) { 42 }

        #expect(value == 42)
    }

    @Test("An operation's error propagates")
    func operationErrorPropagates() async {
        await #expect(throws: NetworkingError.roomNotFound) {
            try await withTimeout(.seconds(5)) { () async throws -> Int in
                throw NetworkingError.roomNotFound
            }
        }
    }

    @Test("A callback that never fires still times out")
    func hungCallbackTimesOut() async {
        let start = ContinuousClock.now

        await #expect(throws: NetworkingError.timeout) {
            try await withTimeout(.milliseconds(100)) { () async throws -> Int in
                // Mirrors a Firebase completion that never runs: the
                // continuation is never resumed and ignores cancellation.
                try await withCheckedThrowingContinuation { (_: CheckedContinuation<Int, Error>) in }
            }
        }
        #expect(ContinuousClock.now - start < .seconds(2))
    }

    @Test("Cancelling the caller ends the wait")
    func cancellationEndsWait() async {
        let task = Task {
            try await withTimeout(.seconds(30)) { () async throws -> Int in
                try await withCheckedThrowingContinuation { (_: CheckedContinuation<Int, Error>) in }
            }
        }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
