//
//  LocalGameSyncManager.swift
//  Networking
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import Foundation
import Observation

/// `GameSyncManager` whose transport is `LocalMultipeerService` instead of
/// Firebase. The host applies actions to the canonical room held by
/// `LocalRoomManager`, which broadcasts the result; guests forward the
/// action to the host and wait for the snapshot.
@MainActor
@Observable
public final class LocalGameSyncManager: GameSyncManager {
    /// Weak ref back to the LocalRoomManager — that's where the MC
    /// transport and the canonical room live.
    public weak var roomManager: LocalRoomManager?

    public init(roomManager: LocalRoomManager) {
        self.roomManager = roomManager
        super.init()
    }

    // MARK: - Game initialization
    @discardableResult
    public override func initializeGame(room: GameRoom, words: [OnlineWord]) async throws -> Bool {
        guard let roomManager, roomManager.isHostInternal else { return false }
        return roomManager.initializeGame(wordIds: words.map(\.id).shuffled())
    }

    // MARK: - Gameplay
    @discardableResult
    public override func perform(_ action: GameAction, room: GameRoom, playerId: String) async throws -> Bool {
        guard let roomManager else { return false }
        if roomManager.isHostInternal {
            return roomManager.applyGameAction(action, by: playerId)
        }
        roomManager.forwardGameAction(action)
        return true
    }
}
