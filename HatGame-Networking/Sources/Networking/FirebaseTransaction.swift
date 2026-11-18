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
///
/// A value written by a newer schema is never rewritten: the transaction
/// aborts with `NetworkingError.unsupportedVersion`. Keys this build does
/// not know are carried into the replacement unchanged.
func runTransaction<Value: VersionedNode>(
    on reference: DatabaseReference,
    _ transform: @escaping @Sendable (Value?) -> Value?
) async throws -> Value? {
    let outcome = TransactionOutcome<Value>()
    return try await withCheckedThrowingContinuation { continuation in
        reference.runTransactionBlock({ currentData in
            if let version = WireSchema.storedVersion(of: currentData.value), !WireSchema.isSupported(version) {
                outcome.record(error: NetworkingError.unsupportedVersion)
                return .abort()
            }
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
                currentData.value = try FirebaseCoding.object(from: next, preservingUnknownKeysIn: currentData.value)
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

/// Writes `value` at `reference` only if nothing is stored there yet.
/// Returns `false` when the location is taken by someone else. A value for
/// which `isOwn` holds counts as created: an earlier attempt whose reply
/// timed out landed after all. A first invocation that sees an empty cache
/// proposes the write; the server rejects it and re-runs the block with the
/// stored value if one exists.
func runCreateIfAbsent<Value: Encodable & Sendable>(
    on reference: DatabaseReference,
    value: Value,
    isOwn: @escaping @Sendable (Any) -> Bool
) async throws -> Bool {
    let object = try FirebaseCoding.object(from: value)
    let foundOwn = Mutex(false)
    return try await withCheckedThrowingContinuation { continuation in
        reference.runTransactionBlock({ currentData in
            if let stored = currentData.value, !(stored is NSNull) {
                let isOwnValue = isOwn(stored)
                foundOwn.withLock { $0 = isOwnValue }
                return .abort()
            }
            foundOwn.withLock { $0 = false }
            currentData.value = object
            return .success(withValue: currentData)
        }, andCompletionBlock: { error, committed, _ in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: committed || foundOwn.withLock { $0 })
            }
        }, withLocalEvents: false)
    }
}

/// Sets one string leaf of the node at `reference` when `decide`, run on the
/// live node, returns a value for it. Every other child is written back
/// exactly as the server holds it, so the check and the write are atomic
/// against concurrent writes anywhere in the node. Returns `.committed`, or
/// `.declined` with the node `decide` last refused (`nil` when the node is
/// gone).
func runLeafTransaction<Node: Decodable & Sendable>(
    on reference: DatabaseReference,
    leaf: String,
    decoding _: Node.Type,
    _ decide: @escaping @Sendable (Node) -> String?
) async throws -> LeafTransactionOutcome<Node> {
    let outcome = Mutex<Result<LeafTransactionOutcome<Node>, any Error>>(.success(.declined(nil)))
    return try await withCheckedThrowingContinuation { continuation in
        reference.runTransactionBlock({ currentData in
            guard let stored = currentData.value, !(stored is NSNull) else {
                // Possibly just an empty cache: proposing no change makes the
                // server re-run the block with the stored value, if any.
                outcome.withLock { $0 = .success(.declined(nil)) }
                return .success(withValue: currentData)
            }
            if let version = WireSchema.storedVersion(of: stored), !WireSchema.isSupported(version) {
                outcome.withLock { $0 = .failure(NetworkingError.unsupportedVersion) }
                return .abort()
            }
            let node: Node
            do {
                node = try FirebaseCoding.decode(Node.self, from: stored)
            } catch {
                outcome.withLock { $0 = .failure(error) }
                return .abort()
            }
            guard let value = decide(node) else {
                outcome.withLock { $0 = .success(.declined(node)) }
                return .abort()
            }
            currentData.childData(byAppendingPath: leaf).value = value
            outcome.withLock { $0 = .success(.committed) }
            return .success(withValue: currentData)
        }, andCompletionBlock: { error, committed, _ in
            let result = outcome.withLock { $0 }
            if let error {
                continuation.resume(throwing: error)
            } else if case let .failure(failure) = result {
                continuation.resume(throwing: failure)
            } else if case .success(.committed) = result, !committed {
                continuation.resume(returning: .declined(nil))
            } else {
                continuation.resume(with: result)
            }
        }, withLocalEvents: false)
    }
}

enum LeafTransactionOutcome<Node: Sendable>: Sendable {
    case committed
    case declined(Node?)
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
