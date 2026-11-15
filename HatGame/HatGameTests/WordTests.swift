//
//  WordTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import HatGame
import Testing

@Suite("Word entry rules")
struct WordEntryRulesTests {
    @Test("Comparison ignores case, diacritics, and surrounding space")
    func normalizes() {
        #expect(WordEntryRules.normalized("  Café ") == WordEntryRules.normalized("cafe"))
        #expect(WordEntryRules.normalized("ÄPFEL") == "apfel")
    }

    @Test("A player can never repeat their own word, in any spelling")
    func ownWordsAlwaysRejected() {
        #expect(WordEntryRules.isDuplicate("Apple", ownWords: ["apple"], otherPlayersWords: [], allowsDuplicates: true))
        #expect(!WordEntryRules.isDuplicate("Pear", ownWords: ["apple"], otherPlayersWords: [], allowsDuplicates: true))
    }

    @Test(
        "Another player's word is rejected only when duplicates are off (E7)",
        arguments: [(false, true), (true, false)]
    )
    func otherPlayersWordsFollowSetting(allowsDuplicates: Bool, isDuplicate: Bool) {
        let result = WordEntryRules.isDuplicate(
            "RÉSUMÉ",
            ownWords: [],
            otherPlayersWords: ["resume"],
            allowsDuplicates: allowsDuplicates
        )

        #expect(result == isDuplicate)
    }

    @Test("Distinct picks skip repeats and exclusions and stop at the limit")
    func distinctRespectsLimit() {
        let picks = WordEntryRules.distinct(
            ["Cat", "cat", "dog", "Owl", "fox", "emu"],
            excluding: ["DOG"],
            limit: 3
        )

        #expect(picks == ["Cat", "Owl", "fox"])
        #expect(WordEntryRules.distinct(["a"], limit: 0).isEmpty)
    }
}

@Suite("Word database")
struct WordDatabaseTests {
    /// The curated Georgian list loads, is substantial, has no duplicates, and
    /// contains only Mkhedruli letters.
    @Test func georgianListLoads() {
        let words = WordDatabase.words(for: .georgian)
        #expect(words.count > 3000)
        #expect(Set(words).count == words.count)
        let isMkhedruli = words.allSatisfy { word in
            word.unicodeScalars.allSatisfy { (0x10D0...0x10F0).contains(Int($0.value)) }
        }
        #expect(isMkhedruli)
    }

    @Test func englishListLoads() {
        let words = WordDatabase.words(for: .english)
        #expect(words.count >= 1500)
        #expect(Set(words.map(WordEntryRules.normalized)).count == words.count)
        #expect(words.allSatisfy { $0 == $0.lowercased() })
    }

    @Test(
        "The list follows the app language; anything but Georgian uses English",
        arguments: [
            ("ka", WordLanguage.georgian),
            ("ka-GE", .georgian),
            ("en", .english),
            ("de", .english),
            (nil, .english),
        ] as [(String?, WordLanguage)]
    )
    func languageMatching(code: String?, expected: WordLanguage) {
        #expect(WordLanguage.matching(languageCode: code) == expected)
    }

    @Test("A bundle without the list reports it missing instead of an empty hat")
    func missingListThrows() {
        let bundle = Bundle(for: BundleToken.self)

        #expect(throws: WordDatabase.LoadError.missingResource("english-words")) {
            try WordDatabase.load(.english, from: bundle)
        }
    }

    @MainActor
    @Test("Random words come from the current language's list")
    func randomWordsUseCurrentLanguage() {
        let pool = Set(WordDatabase.words)
        let picks = WordDatabase.randomWords(count: 5)

        #expect(picks.count == 5)
        #expect(picks.allSatisfy(pool.contains))
        #expect(WordDatabase.randomWords(count: 0).isEmpty)
    }
}

@Suite("Team-name suggestions")
struct TeamNameSuggestionsTests {
    @Test("Team-name suggestions come from the language's own list", arguments: WordLanguage.allCases)
    func teamNameSuggestions(language: WordLanguage) {
        let all = TeamNameSuggestions.all(in: language)
        let picks = TeamNameSuggestions.random(count: 4, in: language)

        #expect(all.count >= 50)
        #expect(Set(all).count == all.count)
        #expect(picks.count == 4)
        #expect(picks.allSatisfy(all.contains))
    }
}

private final class BundleToken {}
