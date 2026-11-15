//
//  Fixtures.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore

enum Fixture {
    static let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)

    static func player(
        _ id: String,
        team: String? = nil,
        joinedOffset: TimeInterval = 0,
        isConnected: Bool = true
    ) -> OnlinePlayer {
        OnlinePlayer(
            id: id,
            deviceId: "device-\(id)",
            name: "Player \(id)",
            teamId: team,
            isConnected: isConnected,
            joinedAt: epoch.addingTimeInterval(joinedOffset)
        )
    }

    static func team(_ id: String, players: [String] = []) -> OnlineTeam {
        OnlineTeam(
            id: id,
            name: "Team \(id)",
            colorHex: "#FF0000",
            playerIds: players
        )
    }

    static func room(
        status: RoomStatus = .waiting,
        teams: [OnlineTeam] = [],
        players: [OnlinePlayer] = [player("host")],
        gameState: OnlineGameState? = nil
    ) -> GameRoom {
        GameRoom(
            id: "ABCDEF",
            hostId: "host",
            status: status,
            teams: teams,
            players: players,
            gameState: gameState,
            createdAt: epoch
        )
    }

    /// Mirrors the Firebase write/read path: Codable → Foundation object
    /// (what `setValue` receives) → JSON → Codable.
    static func firebaseRoundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: firebaseObject(value))
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func firebaseObject<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    static func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
