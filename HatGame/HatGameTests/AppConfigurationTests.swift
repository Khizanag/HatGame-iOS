//
//  AppConfigurationTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import Foundation
@testable import HatGame
import Testing

/// Runs against a throwaway defaults suite, so neither the real settings nor
/// `AppleLanguages` are touched.
@MainActor
@Suite("App configuration")
final class AppConfigurationTests {
    private let suiteName = "HatGameTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    /// The in-app switcher resolves strings through the selected language's
    /// bundle; changing the language flips the resolved value.
    @Test func languageBundleSwitchesLocalizedStrings() {
        let configuration = AppConfiguration(userDefaults: defaults)

        configuration.language = .english
        let english = String(localized: "settings.feedback.title", bundle: configuration.languageBundle)
        configuration.language = .georgian
        let georgian = String(localized: "settings.feedback.title", bundle: configuration.languageBundle)

        #expect(english == "Send Feedback")
        #expect(georgian == "უკუკავშირის გაგზავნა")
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ka"])
        #expect(configuration.effectiveLanguageCode == "ka")
    }

    @Test func choosingTheSystemLanguageClearsTheOverride() {
        let configuration = AppConfiguration(userDefaults: defaults)
        configuration.language = .georgian

        configuration.language = .system

        // Read the suite's own domain: plain lookups fall through to the system's global value.
        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] == nil)
        #expect(!configuration.effectiveLanguageCode.isEmpty)
    }

    @Test func hapticsAreOnByDefault() {
        let configuration = AppConfiguration(userDefaults: defaults)

        #expect(configuration.isHapticsEnabled)
    }

    /// Turning the setting off persists, so the next launch starts with
    /// haptics off too.
    @Test func hapticsSettingPersists() {
        let configuration = AppConfiguration(userDefaults: defaults)

        configuration.isHapticsEnabled = false

        let relaunched = AppConfiguration(userDefaults: defaults)
        #expect(!relaunched.isHapticsEnabled)
    }

    @Test func gameDefaultsMirrorSettings() {
        let configuration = AppConfiguration(userDefaults: defaults)
        configuration.defaultWordsPerPlayer = 6
        configuration.defaultRoundDuration = 45
        configuration.defaultSkippingEnabled = false
        configuration.defaultSkipPenalty = 2
        configuration.allowDuplicateWords = true

        let reloaded = AppConfiguration(userDefaults: defaults)

        #expect(reloaded.gameDefaults == GameDefaults(
            wordsPerPlayer: 6,
            roundDuration: 45,
            isSkippingEnabled: false,
            skipPenalty: 2,
            allowsDuplicateWords: true
        ))
    }

    @Test func skipPenaltyDefaultsToOneAndIgnoresStoredJunk() {
        #expect(AppConfiguration(userDefaults: defaults).defaultSkipPenalty == 1)
        defaults.set(9, forKey: "HatGame.defaultSkipPenalty")
        #expect(AppConfiguration(userDefaults: defaults).defaultSkipPenalty == 1)
    }
}
