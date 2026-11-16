//
//  GameSyncManager.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Foundation
import Observation

/// Moves an online game forward. The transitions themselves live in
/// `OnlineGameRules`; this type runs them inside Firebase transactions, so each
/// one applies to the live state rather than a possibly stale local copy.
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
              let state = OnlineGameRules.initialState(
                  teams: room.teams,
                  players: room.players,
                  wordIds: words.map(\.id).shuffled(),
                  settings: room.settings
              ) else { return false }
        let committed = try await firebaseService.transactGameState(roomId: room.id) { current in
            current == nil ? state : nil
        }
        return committed != nil
    }

    // MARK: - Gameplay
    /// Runs `action` for `playerId`. Returns `false` when the action is not
    /// theirs to take or the game has already moved past it — a duplicate
    /// tap, or a guess after time ran out.
    @discardableResult
    open func perform(_ action: GameAction, room: GameRoom, playerId: String) async throws -> Bool {
        // Cheap local check first: skip the round trip for an action the
        // player could not take even against the state on screen.
        // Server time throughout, so a device with a wrong clock neither
        // cuts a turn short nor accepts a guess after it ended.
        let service = firebaseService
        guard let cached = room.gameState,
              OnlineGameRules.canPerform(
                  action,
                  by: playerId,
                  state: cached,
                  context: GameContext(room: room, now: service.serverNow())
              )
        else { return false }
        let committed = try await service.transactGameState(roomId: room.id) { current in
            current.flatMap { live in
                OnlineGameRules.apply(
                    action,
                    by: playerId,
                    to: live,
                    context: GameContext(room: room, now: service.serverNow())
                )
            }
        }
        guard let next = committed else { return false }
        if next.phase == .finished {
            try await firebaseService.updateRoomStatus(.finished, forRoomId: room.id)
        }
        return true
    }
}
