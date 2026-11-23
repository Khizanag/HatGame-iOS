//
//  AppLanguage.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 01.06.26.
//

import Foundation

/// The app's display language. `.system` follows the device language; the
/// others force a specific localization via a runtime bundle override.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case georgian = "ka"

    var id: String { rawValue }

    /// The `.lproj` code to load, or `nil` to follow the system language.
    var languageCode: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .georgian: "ka"
        }
    }

    /// The glyph beside the option: the device for System, the language's
    /// code letter otherwise.
    var systemImage: String {
        switch self {
        case .system: "iphone"
        case .english: "e.circle"
        case .georgian: "k.circle"
        }
    }

    var displayName: String {
        switch self {
        case .system: localized("settings.language.system")
        case .english: localized("settings.language.english")
        case .georgian: localized("settings.language.georgian")
        }
    }
}
