//
//  OnlineGameSetup.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Networking
import SwiftUI

/// Runs the host's setup work for a started online or nearby game — draw
/// the automatic word pool, then write the first game state — retrying with
/// backoff until it lands. Both flow views call it from
/// `.task(id: setupStep)`, so it restarts when the step changes and stops
/// once the game state exists or the view goes away.
@MainActor
enum OnlineGameSetup {
    static func run(
        _ step: GameSetupStep?,
        roomManager: RoomManager,
        gameSyncManager: GameSyncManager
    ) async {
        guard let step else { return }
        // Drawn once: every retry sends the same word ids, so an attempt
        // that timed out but landed is rewritten rather than duplicated.
        let generated = step == .generateWords ? automaticWords(for: roomManager) : []
        var attempt = 0
        while !Task.isCancelled {
            let isDone: Bool
            do {
                isDone = try await perform(step, words: generated, roomManager: roomManager, sync: gameSyncManager)
            } catch {
                isDone = false
            }
            if isDone { return }
            attempt += 1
            do {
                try await Task.sleep(for: backoff(afterAttempt: attempt))
            } catch {
                return
            }
        }
    }

    /// 1, 2, 4, then every 8 seconds.
    static func backoff(afterAttempt attempt: Int) -> Duration {
        .seconds(1 << min(max(attempt - 1, 0), 3))
    }
}

// MARK: - Steps
private extension OnlineGameSetup {
    static func perform(
        _ step: GameSetupStep,
        words: [OnlineWord],
        roomManager: RoomManager,
        sync: GameSyncManager
    ) async throws -> Bool {
        switch step {
        case .generateWords:
            try await roomManager.fillRandomWords(words)
            return true
        case .initializeGame:
            guard let room = roomManager.room, room.gameState == nil else { return true }
            let pool = try await roomManager.getWords()
            let isStarted = try await sync.initializeGame(room: room, words: pool)
            // `false` means either someone else already started it or the
            // pool was not readable yet; only the latter needs another try.
            return isStarted || roomManager.room?.gameState != nil
        }
    }

    static func automaticWords(for roomManager: RoomManager) -> [OnlineWord] {
        guard let room = roomManager.room, let hostId = roomManager.currentPlayerId else { return [] }
        let count = max(1, room.settings.wordsPerPlayer * room.players.count)
        return WordDatabase.randomWords(count: count).map { OnlineWord(text: $0, addedByPlayerId: hostId) }
    }
}
