//
//  RoomRulesTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("RoomRules")
struct RoomRulesTests {
    private static func lobby() -> GameRoom {
        Fixture.room(
            teams: [Fixture.team("red"), Fixture.team("blue", createdOffset: 1)],
            players: [
                Fixture.player("host"),
                Fixture.player("p1", joinedOffset: 1),
                Fixture.player("p2", joinedOffset: 2),
                Fixture.player("p3", joinedOffset: 3),
            ]
        )
    }

    /// Both sides of the player ↔ team relationship agree.
    private static func expectConsistent(_ room: GameRoom, sourceLocation: SourceLocation = #_sourceLocation) {
        for player in room.players {
            let listedIn = room.teams.filter { $0.playerIds.contains(player.id) }.map(\.id)
            #expect(listedIn == player.teamId.map { [$0] } ?? [], sourceLocation: sourceLocation)
        }
        for team in room.teams {
            #expect(Set(team.playerIds).count == team.playerIds.count, sourceLocation: sourceLocation)
        }
    }

    // MARK: - Authority
    @Test("Team management and starting belong to the host")
    func authority() {
        let room = Self.lobby()

        for action in [RoomAction.createTeam(name: "x", colorHex: "#000"), .removeTeam(teamId: "red"), .startGame] {
            #expect(RoomRules.canPerform(action, by: "host", in: room))
            #expect(!RoomRules.canPerform(action, by: "p1", in: room))
        }
        for action in [RoomAction.joinTeam(teamId: "red"), .leaveTeam, .submitWords(["w"])] {
            #expect(RoomRules.canPerform(action, by: "p1", in: room))
            #expect(!RoomRules.canPerform(action, by: "stranger", in: room))
        }
    }

    // MARK: - Players
    @Test("Players join only while the lobby is open, never under an existing id")
    func addPlayer() throws {
        let room = Self.lobby()
        var started = room
        started.status = .playing

        let joined = try #require(RoomRules.addPlayer(Fixture.player("new", joinedOffset: 9), to: room))

        #expect(joined.players.last?.id == "new")
        #expect(RoomRules.addPlayer(Fixture.player("host"), to: room) == nil)
        #expect(RoomRules.addPlayer(Fixture.player("late"), to: started) == nil)
    }

    @Test("Leaving the lobby removes the player from the room and their team")
    func playerLeftLobby() throws {
        let inTeam = try #require(RoomRules.joinTeam("red", playerId: "p1", in: Self.lobby()))

        let left = try #require(RoomRules.playerLeft("p1", from: inTeam))

        #expect(!left.players.contains { $0.id == "p1" })
        #expect(left.teams.allSatisfy { !$0.playerIds.contains("p1") })
        #expect(RoomRules.playerLeft("p1", from: left) == nil)
    }

    @Test("Leaving mid-game keeps the player on their team, disconnected")
    func playerLeftMidGame() throws {
        var room = try #require(RoomRules.joinTeam("red", playerId: "p1", in: Self.lobby()))
        room.status = .playing

        let left = try #require(RoomRules.playerLeft("p1", from: room))

        let player = try #require(left.players.first { $0.id == "p1" })
        #expect(!player.isConnected)
        #expect(player.teamId == "red")
        #expect(RoomRules.playerLeft("p1", from: left) == nil)
    }

    // MARK: - Teams
    @Test("Joining a team moves the player and keeps both sides consistent")
    func joinTeam() throws {
        let red = try #require(RoomRules.joinTeam("red", playerId: "p1", in: Self.lobby()))
        let blue = try #require(RoomRules.joinTeam("blue", playerId: "p1", in: red))

        #expect(blue.players.first { $0.id == "p1" }?.teamId == "blue")
        #expect(blue.teams.first { $0.id == "red" }?.playerIds == [])
        #expect(blue.teams.first { $0.id == "blue" }?.playerIds == ["p1"])
        Self.expectConsistent(blue)
    }

    @Test("Joining is rejected for the same team, an unknown team or player, or a closed lobby")
    func joinTeamPreconditions() throws {
        let red = try #require(RoomRules.joinTeam("red", playerId: "p1", in: Self.lobby()))
        var closed = Self.lobby()
        closed.status = .playing

        #expect(RoomRules.joinTeam("red", playerId: "p1", in: red) == nil)
        #expect(RoomRules.joinTeam("green", playerId: "p1", in: red) == nil)
        #expect(RoomRules.joinTeam("red", playerId: "ghost", in: red) == nil)
        #expect(RoomRules.joinTeam("red", playerId: "p1", in: closed) == nil)
    }

    @Test("Leaving a team clears both sides; leaving with no team is rejected")
    func leaveTeam() throws {
        let red = try #require(RoomRules.joinTeam("red", playerId: "p1", in: Self.lobby()))

        let left = try #require(RoomRules.leaveTeam(playerId: "p1", in: red))

        #expect(left.players.first { $0.id == "p1" }?.teamId == nil)
        Self.expectConsistent(left)
        #expect(RoomRules.leaveTeam(playerId: "p1", in: left) == nil)
    }

    @Test("Creating a team rejects a duplicate id and a closed lobby")
    func createTeam() throws {
        var closed = Self.lobby()
        closed.status = .finished

        let created = try #require(RoomRules.createTeam(Fixture.team("green", createdOffset: 5), in: Self.lobby()))

        #expect(created.teams.map(\.id) == ["red", "blue", "green"])
        #expect(RoomRules.createTeam(Fixture.team("red"), in: Self.lobby()) == nil)
        #expect(RoomRules.createTeam(Fixture.team("green"), in: closed) == nil)
    }

    @Test("Removing a team unassigns its members")
    func removeTeam() throws {
        var room = try #require(RoomRules.joinTeam("red", playerId: "p1", in: Self.lobby()))
        room = try #require(RoomRules.joinTeam("red", playerId: "p2", in: room))

        let removed = try #require(RoomRules.removeTeam("red", in: room))

        #expect(removed.teams.map(\.id) == ["blue"])
        #expect(removed.players.allSatisfy { $0.teamId == nil })
        Self.expectConsistent(removed)
        #expect(RoomRules.removeTeam("red", in: removed) == nil)
    }

    // MARK: - Starting
    @Test("The game starts with two teams of two")
    func startGame() throws {
        var room = Self.lobby()
        #expect(!RoomRules.canStartGame(room))
        #expect(RoomRules.startGame(room) == nil)

        for (player, team) in [("host", "red"), ("p1", "red"), ("p2", "blue"), ("p3", "blue")] {
            room = try #require(RoomRules.joinTeam(team, playerId: player, in: room))
        }
        let started = try #require(RoomRules.startGame(room))

        #expect(RoomRules.canStartGame(room))
        #expect(started.status == .playing)
        #expect(RoomRules.startGame(started) == nil)
        Self.expectConsistent(started)
    }

    @Test("Teams are fixed once the room leaves the lobby", arguments: [
        (RoomStatus.waiting, true), (.setup, true), (.playing, false), (.finished, false),
    ])
    func teamsLockAfterStart(status: RoomStatus, isOpen: Bool) {
        var room = Self.lobby()
        room.status = status

        #expect(RoomRules.canChangeTeams(in: room) == isOpen)
    }

    @Test("A start re-checked against the live room names why it cannot start")
    func startRefusal() throws {
        var room = Self.lobby()
        for (player, team) in [("host", "red"), ("p1", "red"), ("p2", "blue"), ("p3", "blue")] {
            room = try #require(RoomRules.joinTeam(team, playerId: player, in: room))
        }
        let lostPlayer = try #require(RoomRules.leaveTeam(playerId: "p3", in: room))
        let lostTeam = try #require(RoomRules.removeTeam("blue", in: room))
        let started = try #require(RoomRules.startGame(room))

        #expect(RoomRules.startRefusal(room) == nil)
        #expect(RoomRules.startRefusal(lostPlayer) == .notEnoughPlayers)
        #expect(RoomRules.startRefusal(lostTeam) == .notEnoughTeams)
        #expect(RoomRules.startRefusal(started) == .notInLobby)
    }

    @Test("A team with one player blocks the start")
    func startNeedsFullTeams() throws {
        var room = Self.lobby()
        for (player, team) in [("host", "red"), ("p1", "red"), ("p2", "blue")] {
            room = try #require(RoomRules.joinTeam(team, playerId: player, in: room))
        }

        #expect(!RoomRules.canStartGame(room))
    }

    // MARK: - Words
    @Test("Words are accepted once per player, only after the start and before the deal")
    func submitWords() throws {
        var room = Self.lobby()
        #expect(RoomRules.submitWords(playerId: "p1", in: room) == nil)

        room.status = .playing
        let submitted = try #require(RoomRules.submitWords(playerId: "p1", in: room))
        var dealt = submitted
        dealt.gameState = OnlineGameState()

        #expect(submitted.players.first { $0.id == "p1" }?.hasSubmittedWords == true)
        #expect(RoomRules.submitWords(playerId: "p1", in: submitted) == nil)
        #expect(RoomRules.submitWords(playerId: "p2", in: dealt) == nil)
        #expect(RoomRules.submitWords(playerId: "ghost", in: room) == nil)
        #expect(!RoomRules.allWordsSubmitted(submitted))
    }

    @Test("Auto-fill opens every player's gate at once")
    func markAllWordsSubmitted() throws {
        var room = Self.lobby()
        #expect(RoomRules.markAllWordsSubmitted(in: room) == nil)

        room.status = .playing
        let filled = try #require(RoomRules.markAllWordsSubmitted(in: room))

        #expect(RoomRules.allWordsSubmitted(filled))
        #expect(!RoomRules.allWordsSubmitted(Fixture.room(players: [])))
    }

    @Test("Any sequence of lobby moves keeps membership consistent")
    func randomLobbyMovesStayConsistent() {
        var generator = SeededGenerator(seed: 42)
        var room = Self.lobby()
        let playerIds = room.players.map(\.id)
        for step in 0..<200 {
            let player = playerIds.randomElement(using: &generator) ?? "host"
            switch Int.random(in: 0..<4, using: &generator) {
            case 0: room = RoomRules.joinTeam("red", playerId: player, in: room) ?? room
            case 1: room = RoomRules.joinTeam("blue", playerId: player, in: room) ?? room
            case 2: room = RoomRules.leaveTeam(playerId: player, in: room) ?? room
            default:
                let team = Fixture.team("t\(step)", createdOffset: TimeInterval(step))
                room = RoomRules.createTeam(team, in: room) ?? room
                room = RoomRules.joinTeam(team.id, playerId: player, in: room) ?? room
                room = RoomRules.removeTeam(team.id, in: room) ?? room
            }
            Self.expectConsistent(room)
        }
    }
}

/// Deterministic generator so the randomized test is reproducible.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
