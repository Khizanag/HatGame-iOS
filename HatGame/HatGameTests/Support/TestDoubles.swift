//
//  TestDoubles.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

@testable import HatGame

/// Records every save and clear instead of touching the file system.
actor RecordingGameStore: GameStore {
    private(set) var saved: [GameState] = []
    private(set) var clearCount = 0
    private var stored: GameState?

    init(stored: GameState? = nil) {
        self.stored = stored
    }

    var saveCount: Int { saved.count }
    var lastSaved: GameState? { saved.last }

    func load() -> GameState? {
        stored
    }

    func save(_ state: GameState) {
        saved.append(state)
        stored = state
    }

    func clear() {
        clearCount += 1
        stored = nil
    }
}

@MainActor
final class SoundSpy: SoundPlaying {
    private(set) var timeUpCount = 0

    func playTimeUp() {
        timeUpCount += 1
    }
}

/// Keeps History in memory and counts its loads and saves.
actor InMemoryHistoryStore: HistoryStore {
    private(set) var stored: [GameRecord]
    private(set) var loadCount = 0
    private(set) var saveCount = 0

    init(stored: [GameRecord] = []) {
        self.stored = stored
    }

    func load() -> [GameRecord] {
        loadCount += 1
        return stored
    }

    func save(_ records: [GameRecord]) {
        saveCount += 1
        stored = records
    }
}

/// Collects every game the engine hands to History.
@MainActor
final class RecorderSpy: GameRecording {
    private(set) var records: [GameRecord] = []

    func record(_ record: GameRecord) {
        records.append(record)
    }
}
