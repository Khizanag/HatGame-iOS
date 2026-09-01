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
/// emit `ClientAction`s; the host applies them, mutates its in-memory
/// `GameRoom`, then broadcasts a fresh `roomSnapshot` (and `wordsSnapshot`
/// when the words pool changes). Every peer renders from the snapshot it
/// last received.
public enum LocalMessage: Codable, Sendable {
    /// Host → all peers. Full room envelope after a state change.
    case roomSnapshot(GameRoom)
    /// Host → all peers. Pool of words; separate from `roomSnapshot` so we
    /// don't reserialize a hundred words on every score update.
    case wordsSnapshot([OnlineWord])
    /// Guest → host. Identifies the player attached to this MC peer so the
    /// host can add them to the room's players list.
    case helloFromGuest(OnlinePlayer)
    /// Guest → host. A request to mutate state. Host validates against the
    /// authority model before applying.
    case clientAction(ClientAction)
}

public enum ClientAction: Codable, Sendable {
    // Lobby
    case joinTeam(teamId: String)
    case leaveTeam
    case createTeam(name: String, colorHex: String)
    case removeTeam(teamId: String)
    case startGame

    // Word submission
    case submitWords([String])

    // Turn lifecycle
    case startTurn
    case markWordGuessed
    case skipWord
    case endTurn

    // Phase advancement
    case advanceAfterTurnResults
    case advanceAfterRoundResults
}
