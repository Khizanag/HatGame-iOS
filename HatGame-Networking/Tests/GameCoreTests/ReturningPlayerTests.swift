//
//  ReturningPlayerTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("Away explainers")
struct AwayExplainerTests {
    private static let team = Fixture.team("A", players: ["a1", "a2", "a3"])
    private static let otherTeam = Fixture.team("B", players: ["b1", "b2"], createdOffset: 1)

    private static func players(away: Set<String>) -> [OnlinePlayer] {
        ["a1", "a2", "a3"].enumerated().map { index, id in
            Fixture.player(id, team: "A", joinedOffset: Double(index), isConnected: !away.contains(id))
        } + [Fixture.player("b1", team: "B", joinedOffset: 3), Fixture.player("b2", team: "B", joinedOffset: 4)]
    }

    @Test("A disconnected explainer is skipped for the next connected teammate")
    func skipsAwayExplainer() {
        let state = OnlineGameState(teamExplainerIndices: ["A": 0])

        let explainer = OnlineGameRules.explainer(for: Self.team, state: state, players: Self.players(away: ["a1"]))

        #expect(explainer?.id == "a2")
    }

    @Test("Skipping wraps around the team")
    func skipWraps() {
        let state = OnlineGameState(teamExplainerIndices: ["A": 2])

        let explainer = OnlineGameRules.explainer(for: Self.team, state: state, players: Self.players(away: ["a3"]))

        #expect(explainer?.id == "a1")
    }

    @Test("An away player explains only when the whole team is away")
    func allAwayFallsBack() {
        let state = OnlineGameState(teamExplainerIndices: ["A": 1])
        let players = Self.players(away: ["a1", "a2", "a3"])

        #expect(OnlineGameRules.explainer(for: Self.team, state: state, players: players)?.id == "a2")
    }

    @Test("Handing the hat over skips an away explainer and rotates on from the stand-in")
    func handOverSkipsAway() throws {
        let teams = [Self.team, Self.otherTeam]
        let players = Self.players(away: ["a2"])
        let state = OnlineGameState(
            currentTeamIndex: 1,
            teamExplainerIndices: ["A": 1, "B": 0],
            remainingWordIds: ["w1"],
            phase: .turnResults,
            activePlayerId: "b1"
        )

        let next = try #require(OnlineGameRules.advanceAfterTurnResults(state, teams: teams, players: players))

        #expect(next.activePlayerId == "a3")
        #expect(next.explainerIndex(for: "A") == 2)
    }

    @Test("The team that emptied the hat keeps its explainer unless they left")
    func roundCarryOverExplainer() throws {
        let teams = [Self.team, Self.otherTeam]
        let state = OnlineGameState(
            teamExplainerIndices: ["A": 0],
            allWordIds: ["w1"],
            phase: .roundResults,
            activePlayerId: "a1"
        )

        let stays = try #require(
            OnlineGameRules.advanceAfterRoundResults(state, teams: teams, players: Self.players(away: []))
        )
        let covered = try #require(
            OnlineGameRules.advanceAfterRoundResults(state, teams: teams, players: Self.players(away: ["a1"]))
        )

        #expect(stays.activePlayerId == "a1")
        #expect(covered.activePlayerId == "a2")
    }

    @Test("The first explainer of the game is a connected player")
    func initialStateSkipsAway() throws {
        let state = try #require(
            OnlineGameRules.initialState(
                teams: [Self.team, Self.otherTeam],
                players: Self.players(away: ["a1"]),
                wordIds: ["w1"],
                settings: GameSettings(),
                startingTeamIndex: 0
            )
        )

        #expect(state.activePlayerId == "a2")
    }
}

@Suite("Returning players")
struct ReturningPlayerTests {
    private static let now = Fixture.epoch.addingTimeInterval(500)

    private static func room(status: RoomStatus, guestConnected: Bool = false) -> GameRoom {
        var guest = Fixture.player("g1", team: "t1", joinedOffset: 1, isConnected: guestConnected)
        guest.hasSubmittedWords = true
        return Fixture.room(
            status: status,
            teams: [Fixture.team("t1", players: ["g1"])],
            players: [Fixture.player("host"), guest]
        )
    }

    private static func hello(id: String, device: String) -> OnlinePlayer {
        OnlinePlayer(
            id: id,
            deviceId: device,
            name: "Claimed",
            teamId: "t1",
            isReady: true,
            hasSubmittedWords: true,
            isConnected: false,
            joinedAt: .distantPast
        )
    }

    @Test("A device finds its own seat")
    func returningPlayerByDevice() {
        let room = Self.room(status: .playing)

        #expect(RoomRules.returningPlayer(deviceId: "device-g1", in: room)?.id == "g1")
        #expect(RoomRules.returningPlayer(deviceId: "unknown", in: room) == nil)
    }

    @Test("A returning device gets its seat back mid-game, team and words intact")
    func readmitsMidGame() throws {
        let admission = RoomRules.admitGuest(
            Self.hello(id: "fresh-id", device: "device-g1"),
            to: Self.room(status: .playing),
            now: Self.now,
            boundPlayerIds: []
        )

        guard case let .admitted(room, playerId) = admission else {
            Issue.record("Expected admission")
            return
        }
        let seat = try #require(room.players.first { $0.id == "g1" })
        #expect(playerId == "g1")
        #expect(seat.isConnected)
        #expect(seat.teamId == "t1")
        #expect(seat.hasSubmittedWords)
        #expect(room.players.count == 2)
    }

    @Test("A seat bound to another live peer is not handed out")
    func boundSeatIsNotReadmitted() {
        let admission = RoomRules.admitGuest(
            Self.hello(id: "fresh-id", device: "device-g1"),
            to: Self.room(status: .playing, guestConnected: true),
            now: Self.now,
            boundPlayerIds: ["g1"]
        )

        guard case .refused(.gameInProgress) = admission else {
            Issue.record("Expected a mid-game refusal")
            return
        }
    }

    @Test("The host's seat is never handed to a guest")
    func hostSeatIsProtected() {
        let admission = RoomRules.admitGuest(
            Self.hello(id: "fresh-id", device: "device-host"),
            to: Self.room(status: .playing),
            now: Self.now,
            boundPlayerIds: []
        )

        guard case .refused(.gameInProgress) = admission else {
            Issue.record("Expected a mid-game refusal")
            return
        }
    }

    @Test("A new guest joins the lobby with host-owned fields reset")
    func newGuestIsSanitized() throws {
        let admission = RoomRules.admitGuest(
            Self.hello(id: "new", device: "device-new"),
            to: Self.room(status: .waiting),
            now: Self.now,
            boundPlayerIds: []
        )

        guard case let .admitted(room, playerId) = admission else {
            Issue.record("Expected admission")
            return
        }
        let seat = try #require(room.players.first { $0.id == "new" })
        #expect(playerId == "new")
        #expect(seat.teamId == nil)
        #expect(!seat.hasSubmittedWords)
        #expect(!seat.isReady)
        #expect(seat.isConnected)
        #expect(seat.joinedAt == Self.now)
        #expect(seat.name == "Claimed")
    }

    @Test("A guest claiming a taken id is refused")
    func duplicateIdRefused() {
        let admission = RoomRules.admitGuest(
            Self.hello(id: "g1", device: "device-other"),
            to: Self.room(status: .waiting),
            now: Self.now,
            boundPlayerIds: []
        )

        guard case .refused(.duplicate) = admission else {
            Issue.record("Expected a duplicate refusal")
            return
        }
    }
}
