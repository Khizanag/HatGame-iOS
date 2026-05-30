//
//  View+Background.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

extension View {
    func setDefaultBackground() -> some View {
        background(DesignBook.Color.Background.primary.ignoresSafeArea())
    }

    func setDefaultStyle() -> some View {
        modifier(DefaultStyleModifier())
    }
}

// MARK: - Default Style Modifier
private struct DefaultStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .setDefaultBackground()
            .navigationBarTitleDisplayMode(.inline)
            .navigationButtonToolbar()
    }
}
