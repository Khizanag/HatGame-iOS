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
    /// Under Increase Contrast it gains a visible edge, so a card never
    /// relies on a faint fill alone (constitution article 17).
    func cardSurface(cornerRadius: CGFloat = DesignBook.Size.cardCornerRadius) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}

// MARK: - Card surface
private struct CardSurface: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if os(visionOS)
        content.background(.regularMaterial, in: shape)
        #else
        content
            .background(DesignBook.Color.Background.card)
            .clipShape(shape)
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(DesignBook.Color.Text.tertiary, lineWidth: 1)
                }
            }
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
