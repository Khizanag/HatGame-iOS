//
//  View+UppercaseLabel.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

// MARK: - Uppercase label
extension View {
    /// Uppercases small labels (eyebrows, badges) — except in Georgian, where
    /// uppercasing turns Mkhedruli into Mtavruli, a display script that reads
    /// as shouting and is harder to scan.
    func uppercaseLabel() -> some View {
        modifier(UppercaseLabelModifier())
    }
}

// MARK: - Modifier
private struct UppercaseLabelModifier: ViewModifier {
    private let appConfiguration = AppConfiguration.shared

    func body(content: Content) -> some View {
        content
            .textCase(appConfiguration.effectiveLanguageCode == AppLanguage.georgian.rawValue ? nil : .uppercase)
    }
}
