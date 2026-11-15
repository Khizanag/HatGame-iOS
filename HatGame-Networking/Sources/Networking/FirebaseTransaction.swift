//
//  FirebaseTransaction.swift
//  Networking
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import FirebaseDatabase
import Foundation
import Synchronization

/// Runs a read-modify-write of the value at `reference` as a Realtime
/// Database transaction. `transform` sees the live value and returns the
/// replacement, or `nil` to reject. Returns what was committed, or `nil` if
/// `transform` rejected the latest value.
///
/// The first invocation may see `nil` simply because nothing is cached yet.
/// When `transform(nil)` rejects, the unchanged empty value is committed
/// instead of aborting: if the server holds data, it refuses the stale
/// write and re-runs `transform` with the real value.
func runTransaction<Value: Codable & Sendable>(
    on reference: DatabaseReference,
    _ transform: @escaping @Sendable (Value?) -> Value?
) async throws -> Value? {
    let outcome = TransactionOutcome<Value>()
    return try await withCheckedThrowingContinuation { continuation in
        reference.runTransactionBlock({ currentData in
            let current: Value?
            do {
                current = try FirebaseCoding.decodeIfPresent(Value.self, from: currentData.value)
            } catch {
                outcome.record(error: error)
                return .abort()
            }
            guard let next = transform(current) else {
                outcome.record(nil)
                return current == nil ? .success(withValue: currentData) : .abort()
            }
            do {
                currentData.value = try FirebaseCoding.object(from: next)
            } catch {
                outcome.record(error: error)
                return .abort()
            }
            outcome.record(next)
            return .success(withValue: currentData)
        }, andCompletionBlock: { error, committed, _ in
            if let failure = outcome.error ?? error {
                continuation.resume(throwing: failure)
            } else {
                continuation.resume(returning: committed ? outcome.value : nil)
            }
        }, withLocalEvents: false)
    }
}

/// What the last transform invocation decided. Firebase may call the block
/// several times on its own queue; only the final call matters.
private final class TransactionOutcome<Value: Sendable>: Sendable {
    private struct State {
        var value: Value?
        var error: Error?
    }

    private let state = Mutex(State())

    var value: Value? { state.withLock { $0.value } }
    var error: Error? { state.withLock { $0.error } }

    func record(_ value: Value?) {
        state.withLock { $0 = State(value: value, error: nil) }
    }

    func record(error: Error) {
        state.withLock { $0 = State(value: nil, error: error) }
    }
}

/// Codable ↔ the Foundation object graph the Firebase SDK reads and writes.
enum FirebaseCoding {
    static func object<T: Encodable>(from value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value), options: .fragmentsAllowed)
    }

    static func decodeIfPresent<T: Decodable>(_ type: T.Type, from value: Any?) throws -> T? {
        guard let value, !(value is NSNull) else { return nil }
        let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
        return try JSONDecoder().decode(type, from: data)
    }
}
