//
//  LocalMessage.swift
//  Networking
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import Foundation

/// The nearby wire protocol's generation. Hosts advertise it and guests
/// announce it; peers on different generations refuse each other instead of
/// exchanging messages one side cannot decode.
public enum LocalProtocol {
    public static let version = 1
    /// The `discoveryInfo` key carrying the host's `version`.
    public static let discoveryKey = "v"

    public static func isCompatible(_ version: Int?) -> Bool {
        version == Self.version
    }

    public static func isCompatible(discoveryInfo: [String: String]) -> Bool {
        isCompatible(discoveryInfo[discoveryKey].flatMap { Int($0) })
    }
}

/// Wire protocol exchanged between Multipeer Connectivity peers during a
/// local-play session.
///
/// Authority model: only the host mutates the canonical room state. Guests
/// emit `ClientAction`s; the host checks them against `RoomRules` /
/// `OnlineGameRules`, mutates its in-memory `GameRoom`, then broadcasts a fresh
/// `roomSnapshot` (and `wordsSnapshot` when the words pool changes). Every
/// peer renders from the snapshot it last received.
public enum LocalMessage: Codable, Sendable {
    /// Host → all peers. Full room envelope after a state change, stamped
    /// with the host's clock so guests can run countdowns on host time.
    case roomSnapshot(GameRoom, hostTime: Date)
    /// Host → all peers. Pool of words; separate from `roomSnapshot` so we
    /// don't reserialize a hundred words on every score update.
    case wordsSnapshot([OnlineWord])
    /// Guest → host. Identifies the player attached to this MC peer so the
    /// host can add them to the room's players list.
    case helloFromGuest(OnlinePlayer, protocolVersion: Int)
    /// Host → one guest. Its hello was refused.
    case helloRejected(HelloRejection)
    /// Guest → host. A request to mutate state, attributed to the player the
    /// sending peer registered as.
    case clientAction(ClientAction)
    /// Guest → host. The guest is leaving on purpose. Sent before the session
    /// ends so the host updates everyone at once instead of waiting for
    /// MultipeerConnectivity to notice the dropped peer.
    case guestLeaving
    /// Host → all peers. The host closed the room; guests stop at once.
    case roomClosed
}

/// Why a host refused a guest's hello.
public enum HelloRejection: String, Codable, Sendable {
    /// The guest speaks a different `LocalProtocol` version.
    case unsupportedVersion
    /// The game has started and the guest is not a returning player.
    case gameInProgress
    /// Any other refusal, including reasons a newer host adds.
    case refused

    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = HelloRejection(rawValue: rawValue) ?? .refused
    }
}

public enum ClientAction: Codable, Sendable {
    /// Lobby and word-pool changes, checked by `RoomRules`.
    case room(RoomAction)
    /// Gameplay transitions, checked by `OnlineGameRules`.
    case game(GameAction)
}
