//
//  GameStore.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

/// Keeps the single in-progress game across launches.
nonisolated protocol GameStore: Sendable {
    /// The saved game, or `nil` when there is none (or it could not be read).
    func load() async -> GameState?
    func save(_ state: GameState) async
    func clear() async
}
