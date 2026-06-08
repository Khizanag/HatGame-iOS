//
//  Bundle+Language.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 01.06.26.
//

import Foundation

extension Bundle {
    /// The bundle for the user-selected language, or `.main` to follow the
    /// system. Reading this inside a SwiftUI view body registers an observation
    /// dependency on the selected language (via `AppConfiguration`), so views
    /// re-localize in place the instant the language changes — no relaunch.
    static var appLanguage: Bundle {
        AppConfiguration.shared.languageBundle
    }
}

/// Resolves a localization key into the user-selected language.
///
/// `String(localized:)` resolves the development language unless given an
/// explicit `bundle:`; this routes every lookup through `Bundle.appLanguage`.
/// Used in place of `String(localized:)` throughout the app so a language
/// change re-localizes views in place — reading `appLanguage` inside a view
/// body makes that view observe the selected language.
func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .appLanguage)
}
