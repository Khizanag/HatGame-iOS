//
//  WordEntryRules.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// How words entering the hat are compared. "Apple", "apple", and "Äpple"
/// all count as the same word.
nonisolated enum WordEntryRules {
    /// The comparison key for `text`: trimmed, case- and diacritic-folded.
    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Whether `candidate` may not be added. A player never repeats their own
    /// word; repeating another player's word depends on `allowsDuplicates`.
    static func isDuplicate(
        _ candidate: String,
        ownWords: [String],
        otherPlayersWords: [String],
        allowsDuplicates: Bool
    ) -> Bool {
        let key = normalized(candidate)
        if ownWords.contains(where: { normalized($0) == key }) {
            return true
        }
        return !allowsDuplicates && otherPlayersWords.contains { normalized($0) == key }
    }

    /// Up to `limit` words from `candidates`, in order, skipping any that
    /// repeat an earlier candidate or anything in `excluded`.
    static func distinct(_ candidates: [String], excluding excluded: [String] = [], limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        var seen = Set(excluded.map(normalized))
        var result: [String] = []
        for candidate in candidates where seen.insert(normalized(candidate)).inserted {
            result.append(candidate)
            if result.count == limit { break }
        }
        return result
    }
}
