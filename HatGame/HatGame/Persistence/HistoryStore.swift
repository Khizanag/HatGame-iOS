//
//  HistoryStore.swift
//  HatGame
//

/// Keeps the games History shows, newest first, across launches.
nonisolated protocol HistoryStore: Sendable {
    func load() async -> [GameRecord]
    func save(_ records: [GameRecord]) async
}
