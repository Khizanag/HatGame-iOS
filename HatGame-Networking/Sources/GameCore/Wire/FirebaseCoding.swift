//
//  FirebaseCoding.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// Codable ↔ the Foundation object graph the Firebase SDK reads and writes.
/// Lives in GameCore so the exact stored shape can be tested — and replayed
/// against the database rules — without Firebase.
public enum FirebaseCoding {
    public static func object<T: Encodable>(from value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value), options: .fragmentsAllowed)
    }

    public static func dictionary<T: Encodable>(from value: T) throws -> [String: Any] {
        guard let dictionary = try object(from: value) as? [String: Any] else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: [], debugDescription: "Expected a keyed value")
            )
        }
        return dictionary
    }

    public static func decode<T: Decodable>(_ type: T.Type, from value: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
        return try JSONDecoder().decode(type, from: data)
    }

    public static func decodeIfPresent<T: Decodable>(_ type: T.Type, from value: Any?) throws -> T? {
        guard let value, !(value is NSNull) else { return nil }
        return try decode(type, from: value)
    }
}
