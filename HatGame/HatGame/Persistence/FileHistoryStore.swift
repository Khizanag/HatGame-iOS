//
//  FileHistoryStore.swift
//  HatGame
//

import Foundation
import OSLog

/// Persists History as JSON in `Application Support/HatGame/history.json`.
///
/// Writes are atomic. A record that can't be decoded, or was written by a
/// newer schema, is dropped on its own, so one bad entry never empties History.
actor FileHistoryStore: HistoryStore {
    static let shared = FileHistoryStore()

    private static let logger = Logger(subsystem: "com.khizanag.hat-game", category: "FileHistoryStore")
    private static let fileName = "history.json"

    private let directory: URL?
    private let fileManager = FileManager.default

    /// - Parameter directory: Where to keep the file. `nil` uses
    ///   `Application Support/HatGame`.
    init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
    }

    func load() -> [GameRecord] {
        guard let fileURL, fileManager.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let entries = try JSONDecoder().decode([LenientRecord].self, from: data)
            let records = entries.compactMap(\.record)
            if records.count < entries.count {
                Self.logger.notice("Dropped \(entries.count - records.count) unreadable history records")
            }
            return records
        } catch {
            Self.logger.error("Could not read history: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ records: [GameRecord]) {
        guard let directory, let fileURL else { return }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: Self.writingOptions)
        } catch {
            Self.logger.error("Failed to save history: \(error.localizedDescription)")
        }
    }
}

// MARK: - Private
private extension FileHistoryStore {
    /// Decodes one record, or nothing, without failing the whole file.
    struct LenientRecord: Decodable {
        let record: GameRecord?

        init(from decoder: Decoder) throws {
            let record = try? GameRecord(from: decoder)
            self.record = record.flatMap { $0.schemaVersion <= GameRecord.currentSchemaVersion ? $0 : nil }
        }
    }

    var fileURL: URL? {
        directory?.appending(path: Self.fileName, directoryHint: .notDirectory)
    }

    static var writingOptions: Data.WritingOptions {
        #if os(macOS)
        [.atomic]
        #else
        [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #endif
    }

    static func defaultDirectory() -> URL? {
        do {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return base.appending(path: "HatGame", directoryHint: .isDirectory)
        } catch {
            logger.error("No Application Support directory: \(error.localizedDescription)")
            return nil
        }
    }
}
