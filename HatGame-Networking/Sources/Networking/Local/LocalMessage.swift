//
//  LocalMessage.swift
//  Networking
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import Foundation

/// Wire protocol exchanged between Multipeer Connectivity peers during a
/// local-play session.
///
/// Authority model: only the host mutates the canonical room state. Guests
/// emit `ClientAction`s; the host checks them against `RoomRules` /
/// `OnlineGameRules`, mutates its in-memory `GameRoom`, then broadcasts a fresh
/// `roomSnapshot` (and `wordsSnapshot` when the words pool changes). Every
/// peer renders from the snapshot it last received.
public enum LocalMessage: Codable, Sendable {
    /// Host → all peers. Full room envelope after a state change.
    case roomSnapshot(GameRoom)
    /// Host → all peers. Pool of words; separate from `roomSnapshot` so we
    /// don't reserialize a hundred words on every score update.
    case wordsSnapshot([OnlineWord])
    /// Guest → host. Identifies the player attached to this MC peer so the
    /// host can add them to the room's players list.
    case helloFromGuest(OnlinePlayer)
    /// Guest → host. A request to mutate state, attributed to the player the
    /// sending peer registered as.
    case clientAction(ClientAction)
}

public enum ClientAction: Codable, Sendable {
    /// Lobby and word-pool changes, checked by `RoomRules`.
    case room(RoomAction)
    /// Gameplay transitions, checked by `OnlineGameRules`.
    case game(GameAction)
}
