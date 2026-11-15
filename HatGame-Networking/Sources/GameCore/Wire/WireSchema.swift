//
//  WireSchema.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// The generation of the stored room and game-state format. A build reads
/// every version up to `currentVersion` and refuses to rewrite anything
/// newer, so an older client can never downgrade a room a newer one wrote.
public enum WireSchema {
    public static let currentVersion = 1

    public static func isSupported(_ version: Int) -> Bool {
        version <= currentVersion
    }

    /// The `schemaVersion` stored in a raw Firebase node, read before
    /// decoding so a newer format is recognized even when it no longer
    /// decodes.
    public static func storedVersion(of value: Any?) -> Int? {
        (value as? [String: Any])?["schemaVersion"] as? Int
    }
}

/// A node that is read, transformed, and written back whole. Keys outside
/// `knownKeys` belong to a newer build and are carried through untouched.
public protocol VersionedNode: Codable, Sendable {
    var schemaVersion: Int { get }
    static var knownKeys: Set<String> { get }
}

// MARK: - Whole-node writes
extension FirebaseCoding {
    /// Encodes `value` and carries over every key of `stored` this build
    /// does not know, so a transaction by an older client keeps a newer
    /// client's additive fields. Known keys always come from `value`: one it
    /// now omits (a cleared optional) is deleted, not resurrected.
    public static func object<T: VersionedNode>(from value: T, preservingUnknownKeysIn stored: Any?) throws -> Any {
        var encoded = try dictionary(from: value)
        guard let original = stored as? [String: Any] else { return encoded }
        for (key, storedValue) in original where !T.knownKeys.contains(key) && encoded[key] == nil {
            encoded[key] = storedValue
        }
        return encoded
    }
}
