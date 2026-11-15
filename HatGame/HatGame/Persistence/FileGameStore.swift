//
//  FileGameStore.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
import OSLog

/// Persists the active game as JSON in `Application Support/HatGame/active-game.json`.
///
/// Writes are atomic. A file that cannot be decoded, or that was written by a
/// different schema version, is logged and deleted rather than resurrected.
actor FileGameStore: GameStore {
    static let shared = FileGameStore()

    private static let logger = Logger(subsystem: "com.khizanag.hat-game", category: "FileGameStore")
    private static let fileName = "active-game.json"

    private let directory: URL?
    private let fileManager = FileManager.default

    /// - Parameter directory: Where to keep the file. `nil` uses
    ///   `Application Support/HatGame`.
    init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
    }

    func load() -> GameState? {
        guard let fileURL, fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // A read can fail transiently (protected data not yet available);
            // keep the file so the game can still be resumed later.
            Self.logger.error("Could not read saved game: \(error.localizedDescription)")
            return nil
        }
        do {
            let header = try JSONDecoder().decode(SchemaHeader.self, from: data)
            guard header.schemaVersion == GameState.currentSchemaVersion else {
                Self.logger.notice("Discarding saved game with schema \(header.schemaVersion)")
                removeFile(at: fileURL)
                return nil
            }
            let state = try JSONDecoder().decode(GameState.self, from: data)
            guard state.isConsistent else {
                Self.logger.error("Discarding inconsistent saved game")
                removeFile(at: fileURL)
                return nil
            }
            return state
        } catch {
            Self.logger.error("Discarding undecodable saved game: \(error.localizedDescription)")
            removeFile(at: fileURL)
            return nil
        }
    }

    func save(_ state: GameState) {
        guard let directory, let fileURL else { return }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: Self.writingOptions)
        } catch {
            Self.logger.error("Failed to save game: \(error.localizedDescription)")
        }
    }

    func clear() {
        guard let fileURL, fileManager.fileExists(atPath: fileURL.path) else { return }
        removeFile(at: fileURL)
    }
}

// MARK: - Private
private extension FileGameStore {
    struct SchemaHeader: Decodable {
        let schemaVersion: Int
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

    func removeFile(at url: URL) {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            Self.logger.error("Failed to delete saved game: \(error.localizedDescription)")
        }
    }
}
