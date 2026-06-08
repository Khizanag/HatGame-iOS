//
//  AppColorScheme.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import SwiftUI

enum AppColorScheme: String, CaseIterable {
    case light
    case dark
    case system

    var displayName: String {
        switch self {
        case .light:
            localized("settings.appearance.light")
        case .dark:
            localized("settings.appearance.dark")
        case .system:
            localized("settings.appearance.system")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            nil
        }
    }

    var systemImage: String {
        switch self {
        case .light:
            "sun.max.fill"
        case .dark:
            "moon.fill"
        case .system:
            "circle.lefthalf.filled"
        }
    }
}
