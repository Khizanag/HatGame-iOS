//
//  RoomSnapshot.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// One delivery from a room observer.
public enum RoomSnapshot: Sendable {
    case room(GameRoom)
    /// Nothing is stored at the room's path: it was deleted, or never existed.
    case missing
    /// Data exists but this build cannot read it: a newer schema, or a value
    /// that does not decode.
    case unreadable

    /// Classifies the raw value stored at `rooms/<id>`; `nil` or `NSNull`
    /// means nothing is there. A node without an `id` is not a room either:
    /// it is what a late leaf write (a queued presence flag) leaves in the
    /// local cache after the room itself was deleted.
    public init(storedValue value: Any?) {
        guard let value, !(value is NSNull) else {
            self = .missing
            return
        }
        guard (value as? [String: Any])?["id"] != nil else {
            self = .missing
            return
        }
        if let version = WireSchema.storedVersion(of: value), !WireSchema.isSupported(version) {
            self = .unreadable
            return
        }
        do {
            self = .room(try FirebaseCoding.decode(GameRoom.self, from: value))
        } catch {
            self = .unreadable
        }
    }
}
