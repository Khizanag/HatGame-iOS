//
//  WireCompatibilityTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("Wire compatibility")
struct WireCompatibilityTests {
    private static func roomJSON(status: String = "playing", gameState: String? = nil) -> String {
        let state = gameState.map { #","gameState":\#($0)"# } ?? ""
        return #"{"id":"ABCDEF","hostId":"host","status":"\#(status)","settings":{},"createdAt":0\#(state)}"#
    }

    private static func stateJSON(phase: String = "playing", round: Int = 1, extra: String = "") -> String {
        #"{"currentRound":\#(round),"currentTeamIndex":0,"phase":"\#(phase)","roundDuration":60\#(extra)}"#
    }

    @Test("Unknown room status decodes as unsupported")
    func unknownStatus() throws {
        let room = try Fixture.decode(GameRoom.self, json: Self.roomJSON(status: "paused"))

        #expect(room.status == .unsupported)
        #expect(!room.isSupported)
    }

    @Test("Unknown phase decodes as unsupported")
    func unknownPhase() throws {
        let json = Self.roomJSON(gameState: Self.stateJSON(phase: "suddenDeath"))

        let room = try Fixture.decode(GameRoom.self, json: json)

        #expect(room.gameState?.phase == .unsupported)
        #expect(!room.isSupported)
    }

    @Test("Unknown round decodes as unsupported and is excluded from allCases")
    func unknownRound() throws {
        let state = try Fixture.decode(OnlineGameState.self, json: Self.stateJSON(round: 4))

        #expect(state.currentRound == .unsupported)
        #expect(!state.isSupported)
        #expect(OnlineGameRound.allCases == [.first, .second, .third])
        #expect(OnlineGameRound.unsupported.next == nil)
    }

    @Test("Known values stay supported")
    func knownValuesSupported() throws {
        let room = try Fixture.decode(GameRoom.self, json: Self.roomJSON(gameState: Self.stateJSON()))

        #expect(room.isSupported)
        #expect(room.status == .playing)
        #expect(room.gameState?.phase == .playing)
    }

    @Test("Missing collections in game state decode as empty")
    func missingCollectionsAreEmpty() throws {
        let state = try Fixture.decode(OnlineGameState.self, json: Self.stateJSON())

        #expect(state.scores.isEmpty)
        #expect(state.remainingWordIds.isEmpty)
        #expect(state.allWordIds.isEmpty)
        #expect(state.teamExplainerIndices.isEmpty)
        #expect(state.isSkippingEnabled)
    }

    @Test(
        "Malformed game state values throw instead of resetting",
        arguments: [
            #","scores":"oops""#,
            #","remainingWordIds":{"a":1}"#,
            #","teamExplainerIndices":[true]"#,
            #","isSkippingEnabled":"yes""#,
        ]
    )
    func malformedValuesThrow(extra: String) {
        #expect(throws: DecodingError.self) {
            try Fixture.decode(OnlineGameState.self, json: Self.stateJSON(extra: extra))
        }
    }

    @Test("Malformed team playerIds throw")
    func malformedPlayerIdsThrow() {
        #expect(throws: DecodingError.self) {
            try Fixture.decode(OnlineTeam.self, json: ##"{"id":"t","name":"T","colorHex":"#000","playerIds":7}"##)
        }
    }

    /// `OnlineGameRound` is not a `CodingKeyRepresentable` key, so a team's
    /// scores encode as a flat [round, score, round, score…] array, which
    /// Realtime Database stores as an index-keyed node. Changing that shape
    /// would make every stored game unreadable.
    @Test("Scores are stored as round/score pairs in a flat array")
    func scoresStoredShape() throws {
        let state = OnlineGameState(scores: ["t1": [.first: 3, .second: 1, .third: 0]])

        let object = try #require(try Fixture.firebaseObject(state) as? [String: Any])
        let scores = try #require(object["scores"] as? [String: Any])
        let flat = try #require(scores["t1"] as? [Int])

        #expect(flat.count == 6)
        let pairs = stride(from: 0, to: flat.count, by: 2).map { [flat[$0], flat[$0 + 1]] }
        #expect(pairs.sorted { $0[0] < $1[0] } == [[1, 3], [2, 1], [3, 0]])
    }

    @Test("Scores stored as an index-keyed node decode")
    func scoresFromIndexKeyedNode() throws {
        let json = #"{"currentRound":1,"currentTeamIndex":0,"phase":"teamPrep","roundDuration":60,"#
            + #""scores":{"t1":[2,4,1,5]}}"#

        let state = try Fixture.decode(OnlineGameState.self, json: json)

        #expect(state.getScore(for: "t1", in: .first) == 5)
        #expect(state.getScore(for: "t1", in: .second) == 4)
    }

    @Test("Scores survive a Firebase round trip")
    func scoresRoundTrip() throws {
        let state = OnlineGameState(scores: ["t1": [.first: 3, .second: 1, .third: 0]])

        let decoded = try Fixture.firebaseRoundTrip(state)

        #expect(decoded.getScore(for: "t1", in: .first) == 3)
        #expect(decoded.getTotalScore(for: "t1") == 4)
    }
}
