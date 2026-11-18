//
//  AppConfiguration.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Observation
import OSLog
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

nonisolated private let logger = Logger(subsystem: "com.khizanag.hat-game", category: "AppConfiguration")

@Observable
final class AppConfiguration {
    static let shared = AppConfiguration()

    @ObservationIgnored private let userDefaults: UserDefaults

    private static let testModeKey = "HatGame.isTestMode"
    private static let defaultWordsPerPlayerKey = "HatGame.defaultWordsPerPlayer"
    private static let defaultRoundDurationKey = "HatGame.defaultRoundDuration"
    private static let isRightHandedKey = "HatGame.isRightHanded"
    private static let colorSchemeKey = "HatGame.colorScheme"
    private static let appIconKey = "HatGame.appIcon"
    private static let allowDuplicateWordsKey = "HatGame.allowDuplicateWords"
    private static let defaultSkippingEnabledKey = "HatGame.defaultSkippingEnabled"
    private static let defaultSkipPenaltyKey = "HatGame.defaultSkipPenalty"
    private static let isTimeUpSoundEnabledKey = "HatGame.isTimeUpSoundEnabled"
    private static let isHapticsEnabledKey = "HatGame.isHapticsEnabled"
    private static let languageKey = "HatGame.language"

    var isTestMode: Bool {
        didSet {
            userDefaults.set(isTestMode, forKey: Self.testModeKey)
        }
    }

    var defaultWordsPerPlayer: Int {
        didSet {
            userDefaults.set(defaultWordsPerPlayer, forKey: Self.defaultWordsPerPlayerKey)
        }
    }

    var defaultRoundDuration: Int {
        didSet {
            userDefaults.set(defaultRoundDuration, forKey: Self.defaultRoundDurationKey)
        }
    }

    var isRightHanded: Bool {
        didSet {
            userDefaults.set(isRightHanded, forKey: Self.isRightHandedKey)
        }
    }

    var colorScheme: AppColorScheme {
        didSet {
            userDefaults.set(colorScheme.rawValue, forKey: Self.colorSchemeKey)
        }
    }

    var appIcon: AppIcon {
        didSet {
            userDefaults.set(appIcon.rawValue, forKey: Self.appIconKey)
            applyAppIcon(appIcon)
        }
    }

    var allowDuplicateWords: Bool {
        didSet {
            userDefaults.set(allowDuplicateWords, forKey: Self.allowDuplicateWordsKey)
        }
    }

    /// Default value of the per-game "allow skipping" toggle for newly created games.
    var defaultSkippingEnabled: Bool {
        didSet {
            userDefaults.set(defaultSkippingEnabled, forKey: Self.defaultSkippingEnabledKey)
        }
    }

    /// Default points a skip costs in newly created games.
    var defaultSkipPenalty: Int {
        didSet {
            userDefaults.set(defaultSkipPenalty, forKey: Self.defaultSkipPenaltyKey)
        }
    }

    /// Whether to play a sound when a turn's timer runs out.
    var isTimeUpSoundEnabled: Bool {
        didSet {
            userDefaults.set(isTimeUpSoundEnabled, forKey: Self.isTimeUpSoundEnabledKey)
        }
    }

    /// Whether gameplay moments play haptics. Mirrored into
    /// `DesignBook.Haptics.isEnabled`, which every haptic checks.
    var isHapticsEnabled: Bool {
        didSet {
            userDefaults.set(isHapticsEnabled, forKey: Self.isHapticsEnabledKey)
            DesignBook.Haptics.isEnabled = isHapticsEnabled
            }
    }

    /// The app's display language. Changing it overrides the bundle so all
    /// localized strings switch on the next view refresh.
    var language: AppLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: Self.languageKey)
            languageBundle = Self.bundle(for: language)
            persistPreferredLanguage(language)
        }
    }

    /// The bundle backing the selected language, read via `Bundle.appLanguage`.
    /// Observing it re-localizes views the instant the language changes.
    private(set) var languageBundle: Bundle = .main

    /// The locale matching the selected language (the system locale for `.system`).
    var locale: Locale {
        guard let code = language.languageCode else { return Locale.current }
        return Locale(identifier: code)
    }

    /// - Parameter userDefaults: Where settings persist. Tests pass a throwaway
    ///   suite so they never touch the real defaults or `AppleLanguages`.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // Test Mode is a debug tool; a Release build ignores a stored flag.
        #if DEBUG
        isTestMode = userDefaults.bool(forKey: Self.testModeKey)
        #else
        isTestMode = false
        #endif
        defaultWordsPerPlayer = userDefaults.object(forKey: Self.defaultWordsPerPlayerKey) as? Int ?? 10
        defaultRoundDuration = userDefaults.object(forKey: Self.defaultRoundDurationKey) as? Int ?? 60
        isRightHanded = userDefaults.object(forKey: Self.isRightHandedKey) as? Bool ?? true

        if let rawValue = userDefaults.string(forKey: Self.colorSchemeKey),
           let scheme = AppColorScheme(rawValue: rawValue) {
            colorScheme = scheme
        } else {
            colorScheme = .system
        }

        if let storedIcon = userDefaults.string(forKey: Self.appIconKey),
           let icon = AppIcon(rawValue: storedIcon) {
            appIcon = icon
        } else {
            appIcon = .classic
        }

        allowDuplicateWords = userDefaults.object(forKey: Self.allowDuplicateWordsKey) as? Bool ?? false
        defaultSkippingEnabled = userDefaults.object(forKey: Self.defaultSkippingEnabledKey) as? Bool ?? true
        let storedPenalty = userDefaults.object(forKey: Self.defaultSkipPenaltyKey) as? Int
        defaultSkipPenalty = storedPenalty.flatMap { GameRules.skipPenaltyRange.contains($0) ? $0 : nil }
            ?? GameRules.defaultSkipPenalty
        isTimeUpSoundEnabled = userDefaults.object(forKey: Self.isTimeUpSoundEnabledKey) as? Bool ?? true
        isHapticsEnabled = userDefaults.object(forKey: Self.isHapticsEnabledKey) as? Bool ?? true

        if let raw = userDefaults.string(forKey: Self.languageKey),
           let stored = AppLanguage(rawValue: raw) {
            language = stored
        } else {
            language = .system
        }
        languageBundle = Self.bundle(for: language)
        persistPreferredLanguage(language)
        DesignBook.Haptics.isEnabled = isHapticsEnabled
    }

    /// The defaults a new single-device game starts from.
    var gameDefaults: GameDefaults {
        GameDefaults(
            wordsPerPlayer: defaultWordsPerPlayer,
            roundDuration: defaultRoundDuration,
            isSkippingEnabled: defaultSkippingEnabled,
            skipPenalty: defaultSkipPenalty,
            allowsDuplicateWords: allowDuplicateWords
        )
    }

    /// The language the UI is actually shown in — the chosen one, or the
    /// system's pick among the app's localizations.
    var effectiveLanguageCode: String {
        language.languageCode ?? Bundle.main.preferredLocalizations.first ?? AppLanguage.english.rawValue
    }

    private func applyAppIcon(_ icon: AppIcon) {
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else {
            logger.notice("Alternate icons are not supported on this device")
            return
        }

        let desiredName = icon.alternateIconName
        let currentName = UIApplication.shared.alternateIconName

        if currentName == desiredName {
            return
        }

        UIApplication.shared.setAlternateIconName(desiredName) { error in
            if let error = error {
                logger.error("Failed to set app icon \(desiredName ?? "primary"): \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// The `.lproj` bundle for a language, or `.main` to follow the system.
    private static func bundle(for language: AppLanguage) -> Bundle {
        guard let code = language.languageCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }

    /// Persists the choice as the preferred app language so a fresh launch
    /// (before any view reads `languageBundle`) also starts in that language.
    private func persistPreferredLanguage(_ language: AppLanguage) {
        if let code = language.languageCode {
            userDefaults.set([code], forKey: "AppleLanguages")
        } else {
            userDefaults.removeObject(forKey: "AppleLanguages")
        }
    }
}
