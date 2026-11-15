//
//  GameSyncManager.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Foundation
import Observation

/// Moves an online game forward. The transitions themselves live in
/// `GameRules`; this type only decides who may run them and persists the
/// result to Firebase.
@MainActor
@Observable
open class GameSyncManager {
    private let firebaseService = FirebaseService.shared

    public init() {}

    // MARK: - Game initialization
    /// Host-only. Writes the first `OnlineGameState` once every player has
    /// submitted words. Returns `false` when the game already started.
    @discardableResult
    open func initializeGame(room: GameRoom, words: [OnlineWord]) async throws -> Bool {
        guard room.gameState == nil,
              let state = GameRules.initialState(
                  teams: room.teams,
                  players: room.players,
                  wordIds: words.map(\.id).shuffled(),
                  settings: room.settings
              ) else { return false }
        try await firebaseService.updateGameState(state, forRoomId: room.id)
        return true
    }

    // MARK: - Gameplay
    /// Runs `action` for `playerId`. Returns `false` when the action is not
    /// theirs to take or the game has already moved past it — a duplicate
    /// tap, or a guess after time ran out.
    @discardableResult
    open func perform(_ action: GameAction, room: GameRoom, playerId: String) async throws -> Bool {
        guard let state = room.gameState,
              let next = GameRules.apply(action, by: playerId, to: state, context: GameContext(room: room))
        else { return false }
        try await firebaseService.updateGameState(next, forRoomId: room.id)
        if next.phase == .finished {
            try await firebaseService.updateRoomStatus(.finished, forRoomId: room.id)
        }
        return true
    }
}
