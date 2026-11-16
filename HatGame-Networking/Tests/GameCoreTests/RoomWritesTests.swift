//
//  RoomWritesTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("Room writes")
struct RoomWritesTests {
    @Test("Adding a player writes one whole node under its id")
    func addPlayer() throws {
        let updates = try RoomWrites.addPlayer(Fixture.player("p1"))

        let node = try #require(updates["players/p1"] as? [String: Any])
        #expect(updates.count == 1)
        #expect(node["id"] as? String == "p1")
        #expect(node["deviceId"] as? String == "device-p1")
        #expect(node["teamId"] == nil)
    }

    @Test("A flag write touches only its leaf")
    func playerFlag() {
        let updates = RoomWrites.playerFlag(.isConnected, to: false, playerId: "p1")

        #expect(updates.keys.sorted() == ["players/p1/isConnected"])
        #expect(updates["players/p1/isConnected"] as? Bool == false)
    }

    @Test("Removing a team clears every member's teamId in the same update")
    func removeTeam() {
        let updates = RoomWrites.removeTeam("t1", unassigning: ["a", "b"])

        #expect(updates.keys.sorted() == ["players/a/teamId", "players/b/teamId", "teams/t1"])
        #expect(updates.values.allSatisfy { $0 is NSNull })
    }

    @Test("Reassigning moves the player between both teams' lists")
    func reassign() {
        let teams = [Fixture.team("t1", players: ["a", "b"]), Fixture.team("t2", players: ["c"])]

        let updates = RoomWrites.reassign(playerId: "a", previousTeamId: "t1", newTeamId: "t2", teams: teams)

        #expect(updates["players/a/teamId"] as? String == "t2")
        #expect(updates["teams/t1/playerIds"] as? [String] == ["b"])
        #expect(updates["teams/t2/playerIds"] as? [String] == ["c", "a"])
    }

    @Test("Leaving a team deletes the player's teamId")
    func leaveTeam() {
        let teams = [Fixture.team("t1", players: ["a"])]

        let updates = RoomWrites.reassign(playerId: "a", previousTeamId: "t1", newTeamId: nil, teams: teams)

        #expect(updates["players/a/teamId"] is NSNull)
        #expect(updates["teams/t1/playerIds"] as? [String] == [])
    }

    @Test("Filling words writes each word and opens each listed gate")
    func fillWords() throws {
        let words = [OnlineWord(id: "w1", text: "cat", addedByPlayerId: "a")]

        let updates = try RoomWrites.fillWords(words, markSubmitted: ["a", "b"])

        #expect(updates.keys.sorted() == ["players/a/hasSubmittedWords", "players/b/hasSubmittedWords", "words/w1"])
        let word = try #require(updates["words/w1"] as? [String: Any])
        #expect(word["text"] as? String == "cat")
    }

    @Test("A resent submission writes the same word nodes")
    func submissionIsIdempotent() throws {
        let first = try RoomWrites.fillWords(OnlineWord.submission(["cat", "dog"], by: "a"), markSubmitted: ["a"])
        let resent = try RoomWrites.fillWords(OnlineWord.submission(["cat", "dog"], by: "a"), markSubmitted: ["a"])

        #expect(first.keys.sorted() == resent.keys.sorted())
        #expect(first.keys.sorted() == ["players/a/hasSubmittedWords", "words/a-0", "words/a-1"])
    }

    @Test("Different players' submissions never share an id")
    func submissionsAreDisjoint() {
        let ids = (OnlineWord.submission(["x"], by: "a") + OnlineWord.submission(["x"], by: "b")).map(\.id)

        #expect(Set(ids).count == 2)
    }

    @Test("Status writes its raw value")
    func status() {
        #expect(RoomWrites.status(.playing)["status"] as? String == "playing")
    }
}

@Suite("Room snapshot")
struct RoomSnapshotTests {
    @Test("Nothing stored is missing", arguments: [false, true])
    func nothingStored(storesNull: Bool) {
        guard case .missing = RoomSnapshot(storedValue: storesNull ? NSNull() : nil) else {
            Issue.record("Expected .missing")
            return
        }
    }

    @Test("A complete room decodes")
    func completeRoom() throws {
        let stored = try Fixture.firebaseObject(Fixture.room())

        guard case let .room(room) = RoomSnapshot(storedValue: stored) else {
            Issue.record("Expected .room")
            return
        }
        #expect(room.id == "ABCDEF")
    }

    @Test("A malformed room is unreadable")
    func malformedRoom() {
        let stored: [String: Any] = ["id": "ABCDEF", "hostId": 7, "status": "waiting"]

        guard case .unreadable = RoomSnapshot(storedValue: stored) else {
            Issue.record("Expected .unreadable")
            return
        }
    }
}
