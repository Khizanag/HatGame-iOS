//
//  FirebaseDecoding.swift
//  Networking
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import Foundation

/// Firebase Realtime Database has two storage quirks that break naive
/// `Codable` decoders:
///
/// 1. Empty arrays / dictionaries are silently dropped from the stored
///    snapshot. A field written as `teams: []` reads back as a missing key.
/// 2. Collections written via child paths (`rooms/X/teams/{teamId}`) come
///    back as a `[String: Any]` dictionary, not an array — even though the
///    Swift model defines them as `[T]`.
///
/// This helper bridges both cases: returns `[]` when the key is missing, an
/// array when the value is stored as one, or the dictionary's values
/// otherwise.
extension KeyedDecodingContainer {
    func decodeFirebaseCollection<T: Decodable>(
        _ type: [T].Type,
        forKey key: Key
    ) throws -> [T] {
        guard contains(key) else { return [] }
        if let asArray = try? decode([T].self, forKey: key) {
            return asArray
        }
        let asDict = try decode([String: T].self, forKey: key)
        return Array(asDict.values)
    }

    /// Convenience for primitive-keyed dictionaries that Firebase may also
    /// drop when empty. Returns `[:]` when the key is missing.
    func decodeFirebaseDictionary<V: Decodable>(
        _ type: [String: V].Type,
        forKey key: Key
    ) throws -> [String: V] {
        guard contains(key) else { return [:] }
        return try decode([String: V].self, forKey: key)
    }
}
