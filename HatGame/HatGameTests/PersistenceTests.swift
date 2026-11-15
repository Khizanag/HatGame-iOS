//
//  PersistenceTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import HatGame
import Testing

@MainActor
@Suite("Game state coding")
struct GameStateCodingTests {
    @Test("A fresh setup state round-trips through JSON")
    func freshStateRoundTrips() throws {
        let state = Fixtures.state()

        #expect(try roundTrip(state) == state)
    }

    @Test("A mid-game state with scores, roles, carry-over, and a paused turn round-trips")
    func midGameStateRoundTrips() throws {
        var generator = SeededGenerator()
        var state = Fixtures.started(teams: Fixtures.teams(count: 3)).clearingRound(remaining: .seconds(9))
        state = GameRules.beginTurn(state, explainerIndex: nil, using: &generator)
        state = GameRules.pause(state, remaining: .milliseconds(4_250))

        let decoded = try roundTrip(state)

        #expect(decoded == state)
        #expect(decoded.round == .second)
        #expect(decoded.turn?.remaining == .milliseconds(4_250))
        #expect(decoded.scoreboard.hasAnyScore)
    }

    @Test("Teams keep their color through coding")
    func teamColorRoundTrips() throws {
        let team = Team(name: "Red", color: TeamDefaultColorGenerator.defaultColors[1])

        let decoded = try JSONDecoder().decode(Team.self, from: JSONEncoder().encode(team))

        #expect(decoded == team)
        #expect(decoded.color.isApproximatelyEqual(to: TeamDefaultColorGenerator.defaultColors[1]))
    }

    private func roundTrip(_ state: GameState) throws -> GameState {
        try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
    }
}

@Suite("File game store")
final class FileGameStoreTests {
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: "FileGameStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private var fileURL: URL { directory.appending(path: "active-game.json") }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("Nothing saved loads as nil")
    func emptyStoreLoadsNil() async {
        let store = FileGameStore(directory: directory)

        #expect(await store.load() == nil)
    }

    @Test("A saved game loads back, and clearing removes it")
    func saveLoadClear() async {
        let store = FileGameStore(directory: directory)
        let state = Fixtures.playing()

        await store.save(state)
        #expect(await store.load() == state)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        await store.clear()
        #expect(await store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        await store.clear()
    }

    @Test("A corrupt file loads as nil and is deleted")
    func corruptFileIsDeleted() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)
        let store = FileGameStore(directory: directory)

        #expect(await store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("A file from another schema version loads as nil and is deleted")
    func schemaMismatchIsDeleted() async throws {
        var state = Fixtures.started()
        state.schemaVersion = GameState.currentSchemaVersion + 1
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: fileURL)
        let store = FileGameStore(directory: directory)

        #expect(await store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("A file that decodes but cannot be played from loads as nil and is deleted")
    func inconsistentFileIsDeleted() async throws {
        var state = Fixtures.started()
        state.currentTeamId = UUID()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: fileURL)
        let store = FileGameStore(directory: directory)

        #expect(await store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("A file that cannot be read is kept for a later attempt")
    func unreadableFileIsKept() async throws {
        // A directory at the file's path makes the read fail without being a decode error.
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
        let store = FileGameStore(directory: directory)

        #expect(await store.load() == nil)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
