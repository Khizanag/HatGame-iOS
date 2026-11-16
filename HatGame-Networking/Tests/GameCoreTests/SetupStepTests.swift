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

    @Test("A stand-in starts the game when the host is away")
    func standInInitializes() {
        let room = Self.room(submitted: ["host", "guest"], offline: ["host"])

        #expect(RoomRules.pendingSetupStep(in: room, for: "guest") == .initializeGame)
    }
}
