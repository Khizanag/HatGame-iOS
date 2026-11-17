//
//  View+Background.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

extension View {
    /// The app's backdrop color behind a screen. visionOS keeps the system
    /// glass window instead: an opaque fill there hides people's surroundings
    /// (HIG materials.md, visionOS).
    @ViewBuilder
    func setDefaultBackground() -> some View {
        modifier(ScreenBackground())
    }

    func setDefaultStyle(titleDisplay: NavigationTitleDisplay = .inline) -> some View {
        modifier(DefaultStyleModifier(titleDisplay: titleDisplay))
    }

    /// The surface of a content card: the card color on iOS and macOS, the
    /// regular material on visionOS, where an opaque fill reads as a hole in
    /// the glass window.
    @ViewBuilder
    func cardSurface(cornerRadius: CGFloat = DesignBook.Size.cardCornerRadius) -> some View {
        #if os(visionOS)
        background(.regularMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        #else
        background(DesignBook.Color.Background.card)
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        #endif
    }
}

// MARK: - Default Style Modifier
private struct DefaultStyleModifier: ViewModifier {
    let titleDisplay: NavigationTitleDisplay

    func body(content: Content) -> some View {
        content
            .setDefaultBackground()
            .navigationTitleDisplay(titleDisplay)
            .navigationButtonToolbar()
    }
}

// MARK: - Screen background
extension EnvironmentValues {
    /// False inside a sheet at a partial height, so the system's Liquid Glass
    /// sheet shows through instead of the opaque screen color. At full height
    /// the system makes the sheet opaque on its own.
    @Entry var showsScreenBackground = true
}

private struct ScreenBackground: ViewModifier {
    @Environment(\.showsScreenBackground) private var showsScreenBackground

    func body(content: Content) -> some View {
        #if os(visionOS)
        content
        #else
        if showsScreenBackground {
            content.background(DesignBook.Color.Background.primary.ignoresSafeArea())
        } else {
            content
        }
        #endif
    }
}
