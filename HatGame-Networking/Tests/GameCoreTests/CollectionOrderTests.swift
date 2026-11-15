//
//  CollectionOrderTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("Deterministic collection order")
struct CollectionOrderTests {
    private struct Box: Decodable {
        let items: [String]

        private enum CodingKeys: String, CodingKey { case items }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            items = try container.decodeFirebaseCollection([String].self, forKey: .items)
        }
    }

    @Test("Dictionary-shaped collections decode sorted by key")
    func dictionaryDecodesSortedByKey() throws {
        let json = #"{"items":{"c":"third","a":"first","b":"second"}}"#

        let box = try Fixture.decode(Box.self, json: json)

        #expect(box.items == ["first", "second", "third"])
    }

    @Test("Array-shaped collections keep their stored order")
    func arrayKeepsOrder() throws {
        let box = try Fixture.decode(Box.self, json: #"{"items":["z","y"]}"#)

        #expect(box.items == ["z", "y"])
    }

    @Test("Teams order by creation time, then id")
    func teamsOrderByCreation() throws {
        let room = Fixture.room(teams: [
            Fixture.team("b", createdOffset: 20),
            Fixture.team("z", createdOffset: 10),
            Fixture.team("a", createdOffset: 20),
        ])

        let decoded = try Fixture.firebaseRoundTrip(room)

        #expect(decoded.teams.map(\.id) == ["z", "a", "b"])
        #expect(room.teams.map(\.id) == ["z", "a", "b"])
    }

    @Test("Legacy teams without createdAt order by id")
    func legacyTeamsOrderById() throws {
        let json = """
        {"id":"ABCDEF","hostId":"host","status":"waiting","settings":{},"createdAt":0,
         "teams":{"t2":{"id":"t2","name":"B","colorHex":"#000"},"t1":{"id":"t1","name":"A","colorHex":"#000"}}}
        """

        let decoded = try Fixture.decode(GameRoom.self, json: json)

        #expect(decoded.teams.map(\.id) == ["t1", "t2"])
    }

    @Test("Players order by join time, then id")
    func playersOrderByJoin() throws {
        let room = Fixture.room(players: [
            Fixture.player("late", joinedOffset: 30),
            Fixture.player("host", joinedOffset: 0),
            Fixture.player("mid", joinedOffset: 10),
        ])

        let decoded = try Fixture.firebaseRoundTrip(room)

        #expect(decoded.players.map(\.id) == ["host", "mid", "late"])
    }

    @Test("Appending then normalizing matches what a peer decodes")
    func hostOrderMatchesDecodedOrder() throws {
        var room = Fixture.room(teams: [Fixture.team("m", createdOffset: 50)])
        room.teams.append(Fixture.team("a", createdOffset: 10))

        let normalized = room.canonicallyOrdered()
        let decoded = try Fixture.firebaseRoundTrip(room)

        #expect(normalized.teams.map(\.id) == decoded.teams.map(\.id))
    }
}
