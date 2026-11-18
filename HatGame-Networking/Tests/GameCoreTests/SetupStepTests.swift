//
//  SetupStepTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("Game setup step")
struct SetupStepTests {
    private static func room(
        status: RoomStatus = .playing,
        isAutomatic: Bool = false,
        submitted: Set<String> = [],
        offline: Set<String> = [],
        hasGameState: Bool = false
    ) -> GameRoom {
        var room = Fixture.room(
            status: status,
            players: ["host", "guest"].enumerated().map { index, id in
                var player = Fixture.player(id, joinedOffset: Double(index), isConnected: !offline.contains(id))
                player.hasSubmittedWords = submitted.contains(id)
                return player
            },
            gameState: hasGameState ? OnlineGameState() : nil
        )
        room.settings.isAutomaticWords = isAutomatic
        return room
    }

    @Test("Nothing to do before the game starts or once it has a state")
    func nothingOutsideSetup() {
        #expect(RoomRules.pendingSetupStep(in: Self.room(status: .waiting), for: "host") == nil)
        #expect(RoomRules.pendingSetupStep(
            in: Self.room(submitted: ["host", "guest"], hasGameState: true),
            for: "host"
        ) == nil)
    }

    @Test("The host draws the automatic pool; guests wait")
    func automaticWords() {
        let room = Self.room(isAutomatic: true)

        #expect(RoomRules.pendingSetupStep(in: room, for: "host") == .generateWords)
        #expect(RoomRules.pendingSetupStep(in: room, for: "guest") == nil)
    }

    @Test("The host writes the first state once every word is in")
    func initializeWhenSubmitted() {
        #expect(RoomRules.pendingSetupStep(in: Self.room(submitted: ["host"]), for: "host") == nil)
        #expect(RoomRules.pendingSetupStep(in: Self.room(submitted: ["host", "guest"]), for: "host") == .initializeGame)
        #expect(RoomRules.pendingSetupStep(in: Self.room(submitted: ["host", "guest"]), for: "guest") == nil)
    }

    @Test("Players who left are not waited for")
    func absentPlayersAreNotWaitedFor() {
        let room = Self.room(submitted: ["host"], offline: ["guest"])

        #expect(RoomRules.allWordsSubmitted(room))
        #expect(RoomRules.pendingSetupStep(in: room, for: "host") == .initializeGame)
        #expect(!RoomRules.allWordsSubmitted(Self.room(offline: ["host", "guest"])))
    }

    @Test("The host may start with the words already in")
    func startWithSubmittedWords() {
        let partial = Self.room(submitted: ["host"])

        #expect(RoomRules.canStartWithSubmittedWords(partial))
        #expect(RoomRules.pendingSetupStep(in: partial, for: "host") == nil)
        #expect(RoomRules.pendingSetupStep(in: partial, for: "host", startsWithSubmittedWords: true) == .initializeGame)
    }

    @Test("Starting early needs at least one submission and typed words")
    func startEarlyPreconditions() {
        #expect(!RoomRules.canStartWithSubmittedWords(Self.room()))
        #expect(RoomRules.pendingSetupStep(in: Self.room(), for: "host", startsWithSubmittedWords: true) == nil)
        #expect(!RoomRules.canStartWithSubmittedWords(Self.room(isAutomatic: true, submitted: ["host"])))
        #expect(!RoomRules.canStartWithSubmittedWords(Self.room(submitted: ["host", "guest"])))
    }

    @Test("A stand-in starts the game when the host is away")
    func standInInitializes() {
        let room = Self.room(submitted: ["host", "guest"], offline: ["host"])

        #expect(RoomRules.pendingSetupStep(in: room, for: "guest") == .initializeGame)
    }

    @Test("A stand-in draws the automatic pool when the host drops after Start")
    func standInGeneratesWords() {
        let room = Self.room(isAutomatic: true, offline: ["host"])

        #expect(RoomRules.pendingSetupStep(in: room, for: "guest") == .generateWords)
        #expect(RoomRules.pendingSetupStep(in: room, for: "host") == .generateWords)
    }

    @Test("Automatic word ids are positional, so two generators fill the same entries")
    func automaticWordIdsAreDeterministic() {
        let first = OnlineWord.automatic(["sun", "moon"], by: "host")
        let second = OnlineWord.automatic(["star", "sky"], by: "guest")

        #expect(first.map(\.id) == ["auto-0", "auto-1"])
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.map(\.text) == ["sun", "moon"])
    }
}
