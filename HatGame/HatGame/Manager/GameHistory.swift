//
//  GameHistory.swift
//  HatGame
//

import Foundation
import Observation

/// Takes a finished game into History.
@MainActor
protocol GameRecording: AnyObject {
    func record(_ record: GameRecord)
}

/// The games played on this device, newest first. Loads once, then keeps the
/// store in step with every change; writes run one after another so the file
/// always ends with the latest list.
@MainActor
@Observable
final class GameHistory: GameRecording {
    static let shared = GameHistory()

    /// The most History keeps; the oldest games leave first.
    static let capacity = 200

    private(set) var records: [GameRecord] = []
    private(set) var isLoaded = false

    @ObservationIgnored private let store: any HistoryStore
    @ObservationIgnored private var pendingTask: Task<Void, Never>?

    init(store: any HistoryStore = FileHistoryStore.shared) {
        self.store = store
    }

    /// Reads the store the first time; later calls only wait for pending writes.
    func load() async {
        enqueue { _ in }
        await pendingTask?.value
    }

    /// Adds a game. A multiplayer game already recorded under the same
    /// `sourceKey` is left as it is.
    func record(_ record: GameRecord) {
        enqueue { records in
            if let key = record.sourceKey, records.contains(where: { $0.sourceKey == key }) {
                return
            }
            records.removeAll { $0.id == record.id }
            records.insert(record, at: 0)
            records.sort { $0.endedAt > $1.endedAt }
            if records.count > Self.capacity {
                records.removeLast(records.count - Self.capacity)
            }
        }
    }

    func delete(_ id: GameRecord.ID) {
        enqueue { records in
            records.removeAll { $0.id == id }
        }
    }

    func deleteAll() {
        enqueue { records in
            records.removeAll()
        }
    }

    func record(withId id: GameRecord.ID) -> GameRecord? {
        records.first { $0.id == id }
    }

    /// Resolves once every change issued so far is on disk.
    func waitForPendingWrites() async {
        await pendingTask?.value
    }
}

// MARK: - Private
private extension GameHistory {
    /// Runs `change` after the load and every earlier change, then saves when
    /// it changed anything.
    func enqueue(_ change: @escaping (inout [GameRecord]) -> Void) {
        let previous = pendingTask
        let store = store
        pendingTask = Task {
            await previous?.value
            if !isLoaded {
                let loaded = await store.load()
                records = loaded.sorted { $0.endedAt > $1.endedAt }
                isLoaded = true
            }
            var next = records
            change(&next)
            guard next != records else { return }
            records = next
            await store.save(next)
        }
    }
}
