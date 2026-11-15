//
//  GameRoomCodingTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("GameRoom coding")
struct GameRoomCodingTests {
    @Test("Players and teams encode as dictionaries keyed by id")
    func collectionsEncodeKeyedById() throws {
        let room = Fixture.room(
            teams: [Fixture.team("t1", players: ["host"])],
            players: [Fixture.player("host", team: "t1"), Fixture.player("guest")]
        )

        let object = try #require(try Fixture.firebaseObject(room) as? [String: Any])
        let players = try #require(object["players"] as? [String: Any])
        let teams = try #require(object["teams"] as? [String: Any])

        #expect(Set(players.keys) == ["host", "guest"])
        #expect(Set(teams.keys) == ["t1"])
    }

    @Test("Firebase round trip keeps every player and team")
    func firebaseRoundTrip() throws {
        let room = Fixture.room(
            teams: [Fixture.team("t1", players: ["host"])],
            players: [Fixture.player("host", team: "t1"), Fixture.player("guest")]
        )

        let decoded = try Fixture.firebaseRoundTrip(room)

        #expect(Set(decoded.players.map(\.id)) == ["host", "guest"])
        #expect(decoded.players.first { $0.id == "host" }?.teamId == "t1")
        #expect(decoded.teams.map(\.id) == ["t1"])
        #expect(decoded.hostId == "host")
    }

    @Test("Multipeer round trip through JSONEncoder keeps the room intact")
    func multipeerRoundTrip() throws {
        let room = Fixture.room(players: [Fixture.player("host"), Fixture.player("guest")])

        let data = try JSONEncoder().encode(room)
        let decoded = try JSONDecoder().decode(GameRoom.self, from: data)

        #expect(Set(decoded.players.map(\.id)) == ["host", "guest"])
    }

    @Test("A child write under the host's id merges into one player node")
    func childWriteMergesIntoHostNode() throws {
        let room = Fixture.room(players: [Fixture.player("host")])
        var object = try #require(try Fixture.firebaseObject(room) as? [String: Any])
        var players = try #require(object["players"] as? [String: Any])
        var host = try #require(players["host"] as? [String: Any])
        host["teamId"] = "t1"
        players["host"] = host
        object["players"] = players

        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(GameRoom.self, from: data)

        #expect(decoded.players.count == 1)
        #expect(decoded.players.first?.teamId == "t1")
    }

    @Test("Duplicate ids in memory encode without trapping")
    func duplicateIdsDoNotTrap() throws {
        let room = Fixture.room(players: [Fixture.player("host"), Fixture.player("host")])

        let decoded = try Fixture.firebaseRoundTrip(room)

        #expect(decoded.players.map(\.id) == ["host"])
    }

    @Test("Empty collections survive Firebase dropping them")
    func emptyCollectionsDecodeAsEmpty() throws {
        let json = """
        {"id":"ABCDEF","hostId":"host","status":"waiting","settings":{},"createdAt":0}
        """

        let decoded = try Fixture.decode(GameRoom.self, json: json)

        #expect(decoded.players.isEmpty)
        #expect(decoded.teams.isEmpty)
        #expect(decoded.gameState == nil)
    }
}
