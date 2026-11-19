//
//  WordDatabase.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 26.11.25.
//

import Foundation
import OSLog

/// A language the bundled word lists cover.
nonisolated enum WordLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case georgian = "ka"

    var resourceName: String {
        switch self {
        case .english: "english-words"
        case .georgian: "georgian-words"
        }
    }

    /// The list for an app language code; anything but Georgian uses English.
    static func matching(languageCode: String?) -> WordLanguage {
        languageCode?.lowercased().hasPrefix(georgian.rawValue) == true ? .georgian : .english
    }
}

/// Curated word lists for the "Pick for me" source and auto-fill, shipped as
/// bundled one-word-per-line resources rather than inline arrays (keeps the
/// lists easy to grow and avoids slowing compilation):
///
/// - `georgian-words.txt` — Georgian nouns and verbal nouns (masdars) from
///   Wiktionary's noun lemmas, filtered to common, guessable words.
/// - `english-words.txt` — common, concrete, family-friendly English nouns
///   that work for describing, one-word clues, and miming.
nonisolated enum WordDatabase {
    enum LoadError: Error, Equatable {
        case missingResource(String)
        case empty(String)
    }

    private static let logger = Logger(subsystem: "com.khizanag.hat-game", category: "WordDatabase")
    private static let english = loadLogging(.english)
    private static let georgian = loadLogging(.georgian)

    /// The bundled list for `language`, loaded once; empty if it is missing.
    static func words(for language: WordLanguage) -> [String] {
        switch language {
        case .english: english
        case .georgian: georgian
        }
    }

    /// Reads and cleans one list: trimmed, blank lines dropped, de-duplicated.
    static func load(_ language: WordLanguage, from bundle: Bundle = .main) throws(LoadError) -> [String] {
        guard let url = bundle.url(forResource: language.resourceName, withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else { throw .missingResource(language.resourceName) }

        var seen = Set<String>()
        let words = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        guard !words.isEmpty else { throw .empty(language.resourceName) }
        return words
    }

    private static func loadLogging(_ language: WordLanguage) -> [String] {
        do {
            return try load(language)
        } catch {
            logger.error("Word list unavailable: \(String(describing: error))")
            return []
        }
    }
}

// MARK: - App language
extension WordDatabase {
    /// The list matching the app's current language.
    static var currentLanguage: WordLanguage {
        .matching(languageCode: AppConfiguration.shared.effectiveLanguageCode)
    }

    /// Words in the app's current language; empty if that list is missing.
    static var words: [String] {
        words(for: currentLanguage)
    }

    /// Returns a random subset of `count` words in the app's current language,
    /// each at most `maxLength` characters.
    static func randomWords(count: Int, maxLength: Int = .max) -> [String] {
        guard count > 0 else { return [] }
        return Array(words.filter { $0.count <= maxLength }.shuffled().prefix(count))
    }
}
