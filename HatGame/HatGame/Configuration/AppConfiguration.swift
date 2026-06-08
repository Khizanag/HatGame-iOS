//
//  AppConfiguration.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@Observable
final class AppConfiguration {
    static let shared = AppConfiguration()

    private static let testModeKey = "HatGame.isTestMode"
    private static let defaultWordsPerPlayerKey = "HatGame.defaultWordsPerPlayer"
    private static let defaultRoundDurationKey = "HatGame.defaultRoundDuration"
    private static let isRightHandedKey = "HatGame.isRightHanded"
    private static let colorSchemeKey = "HatGame.colorScheme"
    private static let appIconKey = "HatGame.appIcon"
    private static let allowDuplicateWordsKey = "HatGame.allowDuplicateWords"
    private static let defaultSkippingEnabledKey = "HatGame.defaultSkippingEnabled"
    private static let isTimeUpSoundEnabledKey = "HatGame.isTimeUpSoundEnabled"
    private static let languageKey = "HatGame.language"

    var isTestMode: Bool {
        didSet {
            UserDefaults.standard.set(isTestMode, forKey: Self.testModeKey)
        }
    }

    var defaultWordsPerPlayer: Int {
        didSet {
            UserDefaults.standard.set(defaultWordsPerPlayer, forKey: Self.defaultWordsPerPlayerKey)
        }
    }

    var defaultRoundDuration: Int {
        didSet {
            UserDefaults.standard.set(defaultRoundDuration, forKey: Self.defaultRoundDurationKey)
        }
    }

    var isRightHanded: Bool {
        didSet {
            UserDefaults.standard.set(isRightHanded, forKey: Self.isRightHandedKey)
        }
    }

    var colorScheme: AppColorScheme {
        didSet {
            UserDefaults.standard.set(colorScheme.rawValue, forKey: Self.colorSchemeKey)
        }
    }

    var appIcon: AppIcon {
        didSet {
            UserDefaults.standard.set(appIcon.rawValue, forKey: Self.appIconKey)
            applyAppIcon(appIcon)
        }
    }

    var allowDuplicateWords: Bool {
        didSet {
            UserDefaults.standard.set(allowDuplicateWords, forKey: Self.allowDuplicateWordsKey)
        }
    }

    /// Default value of the per-game "allow skipping" toggle for newly created games.
    var defaultSkippingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(defaultSkippingEnabled, forKey: Self.defaultSkippingEnabledKey)
        }
    }

    /// Whether to play a sound when a turn's timer runs out.
    var isTimeUpSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isTimeUpSoundEnabled, forKey: Self.isTimeUpSoundEnabledKey)
        }
    }

    /// The app's display language. Changing it overrides the bundle so all
    /// localized strings switch on the next view refresh.
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
            languageBundle = Self.bundle(for: language)
            Self.persistPreferredLanguage(language)
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

    private init() {
        isTestMode = UserDefaults.standard.bool(forKey: Self.testModeKey)
        defaultWordsPerPlayer = UserDefaults.standard.object(forKey: Self.defaultWordsPerPlayerKey) as? Int ?? 10
        defaultRoundDuration = UserDefaults.standard.object(forKey: Self.defaultRoundDurationKey) as? Int ?? 60
        isRightHanded = UserDefaults.standard.object(forKey: Self.isRightHandedKey) as? Bool ?? true

        if let rawValue = UserDefaults.standard.string(forKey: Self.colorSchemeKey),
           let scheme = AppColorScheme(rawValue: rawValue) {
            colorScheme = scheme
        } else {
            colorScheme = .system
        }

        if let storedIcon = UserDefaults.standard.string(forKey: Self.appIconKey),
           let icon = AppIcon(rawValue: storedIcon) {
            appIcon = icon
        } else {
            appIcon = .classic
        }

        allowDuplicateWords = UserDefaults.standard.object(forKey: Self.allowDuplicateWordsKey) as? Bool ?? false
        defaultSkippingEnabled = UserDefaults.standard.object(forKey: Self.defaultSkippingEnabledKey) as? Bool ?? true
        isTimeUpSoundEnabled = UserDefaults.standard.object(forKey: Self.isTimeUpSoundEnabledKey) as? Bool ?? true

        if let raw = UserDefaults.standard.string(forKey: Self.languageKey),
           let stored = AppLanguage(rawValue: raw) {
            language = stored
        } else {
            language = .system
        }
        languageBundle = Self.bundle(for: language)
        Self.persistPreferredLanguage(language)
    }

    func applyStoredAppIcon() {
        applyAppIcon(appIcon)
    }

    private func applyAppIcon(_ icon: AppIcon) {
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Alternate icons are not supported on this device")
            return
        }

        let desiredName = icon.alternateIconName
        let currentName = UIApplication.shared.alternateIconName

        if currentName == desiredName {
            return
        }

        UIApplication.shared.setAlternateIconName(desiredName) { error in
            if let error = error {
                print("Failed to set app icon '\(desiredName ?? "primary")': \(error.localizedDescription)")
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
    private static func persistPreferredLanguage(_ language: AppLanguage) {
        if let code = language.languageCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}
