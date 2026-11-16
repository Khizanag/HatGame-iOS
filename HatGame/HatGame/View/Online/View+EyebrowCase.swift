//
//  View+EyebrowCase.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

// MARK: - Eyebrow case
extension View {
    /// Uppercases a small tracked label above a title, except in Georgian:
    /// uppercasing Mkhedruli yields Mtavruli, a display script that reads
    /// as shouting and is harder to scan at caption sizes.
    func eyebrowUppercase() -> some View {
        modifier(EyebrowUppercaseModifier())
    }
}

// MARK: - Modifier
private struct EyebrowUppercaseModifier: ViewModifier {
    @Environment(\.locale) private var locale

    private var isGeorgian: Bool {
        locale.language.languageCode == Locale.LanguageCode("ka")
    }

    func body(content: Content) -> some View {
        content.textCase(isGeorgian ? nil : .uppercase)
    }
}
