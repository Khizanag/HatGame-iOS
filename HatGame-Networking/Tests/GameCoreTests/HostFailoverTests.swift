//
//  HostFailoverTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("Host failover")
struct HostFailoverTests {
    /// "host" joined first, then "early", "late", and "latest".
    private static func players(offline: Set<String>) -> [OnlinePlayer] {
        [("host", 0.0), ("late", 2), ("early", 1), ("latest", 3)].map { id, offset in
            Fixture.player(id, team: "A", joinedOffset: offset, isConnected: !offline.contains(id))
        }
    }

    private static func context(offline: Set<String>) -> GameContext {
        GameContext(
            hostId: "host",
            teams: [Fixture.team("A")],
            players: players(offline: offline),
            now: Fixture.epoch
        )
    }

    private static let roundResults = OnlineGameState(allWordIds: ["w1"], phase: .roundResults, activePlayerId: "late")

    private static func mayAdvanceRound(_ playerId: String, offline: Set<String>) -> Bool {
        OnlineGameRules.canPerform(
            .advanceAfterRoundResults,
            by: playerId,
            state: roundResults,
            context: context(offline: offline)
        )
    }

    @Test("A connected host acts alone")
    func connectedHostActs() {
        #expect(OnlineGameRules.actingHostId(hostId: "host", players: Self.players(offline: [])) == "host")
        #expect(!Self.mayAdvanceRound("early", offline: []))
    }

    @Test("The longest-connected player stands in for an away host")
    func longestConnectedStandsIn() {
        let players = Self.players(offline: ["host"])

        #expect(OnlineGameRules.actingHostId(hostId: "host", players: players) == "early")
        #expect(Self.mayAdvanceRound("early", offline: ["host"]))
        #expect(!Self.mayAdvanceRound("late", offline: ["host"]))
    }

    @Test("Seniority skips players who are away too")
    func skipsAwayPlayers() {
        let players = Self.players(offline: ["host", "early"])

        #expect(OnlineGameRules.actingHostId(hostId: "host", players: players) == "late")
    }

    @Test("A host who left the room entirely is replaced")
    func missingHostIsReplaced() {
        let players = Self.players(offline: []).filter { $0.id != "host" }

        #expect(OnlineGameRules.actingHostId(hostId: "host", players: players) == "early")
    }

    @Test("With everyone away the host keeps the role")
    func everyoneAway() {
        let players = Self.players(offline: ["host", "early", "late", "latest"])

        #expect(OnlineGameRules.actingHostId(hostId: "host", players: players) == "host")
    }

    @Test("The host keeps authority while flagged away")
    func awayHostKeepsAuthority() {
        #expect(Self.mayAdvanceRound("host", offline: ["host"]))
    }

    @Test("The stand-in may cover a stalled turn")
    func standInCoversStall() {
        let state = OnlineGameState(
            remainingWordIds: ["w1"],
            phase: .playing,
            activePlayerId: "latest",
            timerStartedAt: Fixture.epoch,
            roundDuration: 60
        )
        let context = GameContext(
            hostId: "host",
            teams: [Fixture.team("A")],
            players: Self.players(offline: ["host"]),
            now: Fixture.epoch.addingTimeInterval(60 + OnlineGameRules.stallGraceSeconds + 1)
        )

        #expect(OnlineGameRules.canPerform(.endTurn, by: "early", state: state, context: context))
        #expect(!OnlineGameRules.canPerform(.endTurn, by: "late", state: state, context: context))
    }
}
