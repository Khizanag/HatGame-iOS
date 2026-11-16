//
//  WireSchemaTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("Wire schema")
struct WireSchemaTests {
    private static let newer = WireSchema.currentVersion + 1

    @Test("Rooms and game states are written with the current schema")
    func writesCurrentVersion() throws {
        let room = Fixture.room(status: .playing, gameState: OnlineGameState())

        let object = try #require(try Fixture.firebaseObject(room) as? [String: Any])
        let state = try #require(object["gameState"] as? [String: Any])

        #expect(object["schemaVersion"] as? Int == WireSchema.currentVersion)
        #expect(state["schemaVersion"] as? Int == WireSchema.currentVersion)
    }

    @Test("Nodes stored before versioning read as the first generation")
    func missingVersionIsFirstGeneration() throws {
        let json = #"{"id":"ABCDEF","hostId":"host","status":"playing","settings":{},"createdAt":0,"#
            + #""gameState":{"currentRound":1,"currentTeamIndex":0,"phase":"teamPrep","roundDuration":60}}"#

        let room = try Fixture.decode(GameRoom.self, json: json)

        #expect(room.schemaVersion == 1)
        #expect(room.gameState?.schemaVersion == 1)
        #expect(room.isSupported)
    }

    @Test("A room from a newer schema is unsupported and never decoded")
    func newerRoomIsUnreadable() throws {
        var stored = try #require(try Fixture.firebaseObject(Fixture.room()) as? [String: Any])
        stored["schemaVersion"] = Self.newer

        #expect(!GameRoom(id: "ABCDEF", hostId: "host", schemaVersion: Self.newer).isSupported)
        guard case .unreadable = RoomSnapshot(storedValue: stored) else {
            Issue.record("Expected .unreadable")
            return
        }
    }

    @Test("A newer game state is unsupported and no transition applies to it")
    func newerStateRejectsTransitions() {
        let state = OnlineGameState(schemaVersion: Self.newer, remainingWordIds: ["w1"], activePlayerId: "a")

        #expect(!state.isSupported)
        #expect(OnlineGameRules.startTurn(state, teams: [], now: Fixture.epoch) == nil)
        #expect(OnlineGameRules.endTurn(state) == nil)
    }

    @Test("Stored version is read from the raw node")
    func storedVersion() {
        #expect(WireSchema.storedVersion(of: ["schemaVersion": 3]) == 3)
        #expect(WireSchema.storedVersion(of: ["phase": "playing"]) == nil)
        #expect(WireSchema.storedVersion(of: nil) == nil)
    }

    @Test("Rewriting a state keeps keys a newer build added")
    func unknownKeysSurvive() throws {
        let stored: [String: Any] = [
            "currentRound": 1, "currentTeamIndex": 0, "phase": "playing", "roundDuration": 60,
            "timerStartedAt": 5.0, "futureField": ["a": 1],
        ]
        var next = try FirebaseCoding.decode(OnlineGameState.self, from: stored)
        next.timerStartedAt = nil

        let written = try #require(
            try FirebaseCoding.object(from: next, preservingUnknownKeysIn: stored) as? [String: Any]
        )

        #expect((written["futureField"] as? [String: Int]) == ["a": 1])
        #expect(written["timerStartedAt"] == nil)
        #expect(written["schemaVersion"] as? Int == WireSchema.currentVersion)
    }

    @Test("Known keys cover every encoded field")
    func knownKeysCoverEncoding() throws {
        let state = OnlineGameState(currentWordId: "w", activePlayerId: "a", timerStartedAt: Fixture.epoch)

        let encoded = try FirebaseCoding.dictionary(from: state)

        #expect(Set(encoded.keys).isSubset(of: OnlineGameState.knownKeys))
    }
}
