//
//  RulesScenarioExport.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

/// Writes every app write path — built by the same `RoomWrites` and
/// `FirebaseCoding` the app sends — as an ordered list of REST requests with
/// the outcome the database rules must give. `Scripts/rules-check/run.sh`
/// replays the file against the Realtime Database emulator. Runs only when
/// `HATGAME_RULES_SCENARIO` names the output file.
@Suite("Rules scenario export")
struct RulesScenarioExport {
    private static let outputPath = ProcessInfo.processInfo.environment["HATGAME_RULES_SCENARIO"]

    @Test("Export the rules scenario", .enabled(if: outputPath != nil))
    func export() throws {
        let path = try #require(Self.outputPath)
        var scenario = RulesScenario(code: "ABCDEF")
        try scenario.lobby()
        try scenario.tampering()
        try scenario.game()
        try scenario.teardown()
        let data = try JSONSerialization.data(withJSONObject: scenario.steps, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path))
    }
}

private struct RulesScenario {
    let code: String
    var steps: [[String: Any]] = []

    let host = OnlinePlayer(id: "host", deviceId: "device-host", name: "Host", isReady: true, isConnected: false)
    let guest = OnlinePlayer(id: "guest", deviceId: "device-guest", name: "Guest", isConnected: false)
    let third = OnlinePlayer(id: "third", deviceId: "device-third", name: "Third", isConnected: false)
    let fourth = OnlinePlayer(id: "fourth", deviceId: "device-fourth", name: "Fourth", isConnected: false)
    let red = OnlineTeam(id: "red", name: "Red", colorHex: "#FF0000")
    let blue = OnlineTeam(id: "blue", name: "Blue", colorHex: "#0000FF")

    var room: String { "rooms/\(code)" }

    init(code: String) {
        self.code = code
    }

    mutating func step(_ name: String, _ method: String, _ path: String, _ body: Any? = nil, allowed: Bool) {
        var entry: [String: Any] = ["name": name, "method": method, "path": path, "expect": allowed ? "allow" : "deny"]
        entry["body"] = body
        steps.append(entry)
    }

    mutating func update(_ name: String, _ updates: RoomWrites.Updates, allowed: Bool = true) {
        step(name, "PATCH", room, updates, allowed: allowed)
    }
}

// MARK: - Lobby
private extension RulesScenario {
    mutating func lobby() throws {
        let created = GameRoom(id: code, hostId: host.id, settings: GameSettings(), players: [host])
        step("create room", "PUT", room, try FirebaseCoding.object(from: created), allowed: true)
        step("read room by code", "GET", room, allowed: true)
        step("list all rooms", "GET", "rooms", allowed: false)
        let badRoom = GameRoom(id: "abc", hostId: "x", players: [host])
        let badRoomObject = try FirebaseCoding.object(from: badRoom)
        step("create room under a bad code", "PUT", "rooms/abc", badRoomObject, allowed: false)
        update("host presence armed", RoomWrites.playerFlag(.isConnected, to: true, playerId: host.id))

        update("join", try RoomWrites.addPlayer(guest))
        update("join retried with the same identity", try RoomWrites.addPlayer(guest))
        update("join", try RoomWrites.addPlayer(third))
        update("join", try RoomWrites.addPlayer(fourth))
        update("guest presence armed", RoomWrites.playerFlag(.isConnected, to: true, playerId: guest.id))

        update("add team", try RoomWrites.addTeam(red))
        update("add team", try RoomWrites.addTeam(blue))
        let spare = OnlineTeam(id: "spare", name: "Spare", colorHex: "#00FF00")
        update("add team", try RoomWrites.addTeam(spare))

        var teams = [red, blue, spare]
        try reassign(guest.id, from: nil, to: spare.id, teams: &teams, name: "join team")
        try reassign(guest.id, from: spare.id, to: red.id, teams: &teams, name: "switch team")
        try reassign(host.id, from: nil, to: red.id, teams: &teams, name: "join team")
        try reassign(third.id, from: nil, to: blue.id, teams: &teams, name: "join team")
        try reassign(fourth.id, from: nil, to: spare.id, teams: &teams, name: "join team")
        try reassign(fourth.id, from: spare.id, to: nil, teams: &teams, name: "leave team")
        try reassign(fourth.id, from: nil, to: spare.id, teams: &teams, name: "join team")
        update("remove team", RoomWrites.removeTeam(spare.id, unassigning: [fourth.id]))
        try reassign(fourth.id, from: nil, to: blue.id, teams: &teams, name: "join team")
    }

    mutating func reassign(
        _ playerId: String,
        from previous: String?,
        to next: String?,
        teams: inout [OnlineTeam],
        name: String
    ) throws {
        update(name, RoomWrites.reassign(playerId: playerId, previousTeamId: previous, newTeamId: next, teams: teams))
        for index in teams.indices {
            teams[index].playerIds.removeAll { $0 == playerId }
            if teams[index].id == next { teams[index].playerIds.append(playerId) }
        }
    }
}

// MARK: - Tampering
private extension RulesScenario {
    mutating func tampering() throws {
        update("overwrite hostId", ["hostId": "guest"], allowed: false)
        update("overwrite room id", ["id": "ZZZZZZ"], allowed: false)
        update("overwrite createdAt", ["createdAt": 1.0], allowed: false)
        update("unknown room field", ["isPremium": true], allowed: false)
        update("unknown settings field", ["settings/cheats": true], allowed: false)
        update("unknown player field", ["players/guest/isAdmin": true], allowed: false)
        update("unknown team field", ["teams/red/score": 99], allowed: false)
        update("overwrite a player's deviceId", ["players/guest/deviceId": "stolen"], allowed: false)
        update("overwrite a player's joinedAt", ["players/guest/joinedAt": 0.0], allowed: false)
        let rejoinedLater = OnlinePlayer(
            id: guest.id,
            deviceId: guest.deviceId,
            name: guest.name,
            isConnected: false,
            joinedAt: guest.joinedAt.addingTimeInterval(5)
        )
        update("rewrite a player with another join time", try RoomWrites.addPlayer(rejoinedLater), allowed: false)
        update("player name over 100", ["players/guest/name": String(repeating: "n", count: 101)], allowed: false)
        update("team name over 100", ["teams/red/name": String(repeating: "n", count: 101)], allowed: false)
        update("word over 200", [
            "words/long": ["id": "long", "text": String(repeating: "w", count: 201), "addedByPlayerId": "guest"],
        ], allowed: false)
        update("word with an unknown field", [
            "words/extra": ["id": "extra", "text": "cat", "addedByPlayerId": "guest", "points": 5],
        ], allowed: false)
        update("player id under the wrong key", [
            "players/mallory": try FirebaseCoding.dictionary(from: guest),
        ], allowed: false)
    }
}

// MARK: - Game
private extension RulesScenario {
    mutating func game() throws {
        update("start game", RoomWrites.status(.playing))
        let latecomer = OnlinePlayer(id: "late", deviceId: "device-late", name: "Late", isConnected: false)
        update("new player after the start", try RoomWrites.addPlayer(latecomer), allowed: false)
        update("returning player reconnects", RoomWrites.playerFlag(.isConnected, to: true, playerId: third.id))
        let lineup = [red, blue]
        let switchTeam = RoomWrites.reassign(playerId: guest.id, previousTeamId: red.id, newTeamId: blue.id, teams: lineup)
        update("switch team after the start", switchTeam, allowed: false)
        let leaveTeam = RoomWrites.reassign(playerId: guest.id, previousTeamId: red.id, newTeamId: nil, teams: lineup)
        update("leave team after the start", leaveTeam, allowed: false)
        update("remove a team after the start", RoomWrites.removeTeam(blue.id, unassigning: [third.id]), allowed: false)

        let guestWords = OnlineWord.submission(["cat", "dog"], by: guest.id)
        update("submit words", try RoomWrites.fillWords(guestWords, markSubmitted: [guest.id]))
        update("submit words retried", try RoomWrites.fillWords(guestWords, markSubmitted: [guest.id]))
        let pool = ["sun", "moon"].map { OnlineWord(id: "auto-\($0)", text: $0, addedByPlayerId: host.id) }
        let everyone = [host.id, guest.id, third.id, fourth.id]
        update("automatic fill for everyone", try RoomWrites.fillWords(pool, markSubmitted: everyone))

        try gameStates(wordIds: (guestWords + pool).map(\.id))

        update("finish game", RoomWrites.status(.finished))
    }

    mutating func gameStates(wordIds: [String]) throws {
        let teams = [red, blue]
        let players = [
            OnlinePlayer(id: host.id, deviceId: host.deviceId, name: host.name, teamId: red.id),
            OnlinePlayer(id: guest.id, deviceId: guest.deviceId, name: guest.name, teamId: red.id),
            OnlinePlayer(id: third.id, deviceId: third.deviceId, name: third.name, teamId: blue.id),
            OnlinePlayer(id: fourth.id, deviceId: fourth.deviceId, name: fourth.name, teamId: blue.id),
        ]
        let path = "\(room)/gameState"
        let initial = try #require(
            OnlineGameRules.initialState(
                teams: teams,
                players: players,
                wordIds: wordIds,
                settings: GameSettings(roundDuration: 30),
                startingTeamIndex: 0
            )
        )
        step("initialize game state", "PUT", path, try FirebaseCoding.object(from: initial), allowed: true)

        var state = try #require(OnlineGameRules.startTurn(initial, teams: teams, now: Date()))
        step("start turn", "PUT", path, try FirebaseCoding.object(from: state), allowed: true)
        while let wordId = state.currentWordId, state.phase == .playing {
            state = try #require(OnlineGameRules.markGuessed(state, expectedWordId: wordId, teams: teams, now: Date()))
        }
        step("empty the hat with time to carry", "PUT", path, try FirebaseCoding.object(from: state), allowed: true)
        let roundOver = try #require(OnlineGameRules.advanceAfterTurnResults(state, teams: teams, players: players))
        let nextRound = try #require(
            OnlineGameRules.advanceAfterRoundResults(roundOver, teams: teams, players: players)
        )
        let carried = try #require(OnlineGameRules.startTurn(nextRound, teams: teams, now: Date()))
        step("start a carried-over turn", "PUT", path, try FirebaseCoding.object(from: carried), allowed: true)

        var withFutureField = try FirebaseCoding.dictionary(from: carried)
        withFutureField["suddenDeath"] = ["enabled": true]
        step("game state keeps a newer build's field", "PUT", path, withFutureField, allowed: true)
        var incomplete = try FirebaseCoding.dictionary(from: carried)
        incomplete["phase"] = nil
        step("game state missing its phase", "PUT", path, incomplete, allowed: false)
    }
}

// MARK: - Teardown
private extension RulesScenario {
    mutating func teardown() throws {
        step("presence goes offline", "PUT", "\(room)/players/\(third.id)/isConnected", false, allowed: true)
        step("guest leaves", "DELETE", "\(room)/players/\(fourth.id)", allowed: true)
        let removedFlag = "\(room)/players/\(fourth.id)/isConnected"
        step("queued presence write for a removed player", "PUT", removedFlag, false, allowed: false)

        let feedback = Feedback(id: "fb-1", category: "bug", message: "It works", createdAt: Date())
        step("send feedback", "PUT", "feedback/fb-1", try FirebaseCoding.object(from: feedback), allowed: true)
        step("overwrite feedback", "PUT", "feedback/fb-1", try FirebaseCoding.object(from: feedback), allowed: false)
        step("read feedback", "GET", "feedback", allowed: false)
        var extra = try FirebaseCoding.dictionary(from: Feedback(id: "fb-2", category: "bug", message: "x"))
        extra["rating"] = 5
        step("feedback with an unknown field", "PUT", "feedback/fb-2", extra, allowed: false)

        step("host closes the room", "DELETE", room, allowed: true)
        let closedFlag = "\(room)/players/\(guest.id)/isConnected"
        step("presence write after the room closed", "PUT", closedFlag, false, allowed: false)
    }
}
