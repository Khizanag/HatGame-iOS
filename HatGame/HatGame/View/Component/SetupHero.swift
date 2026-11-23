//
//  SetupHero.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 31.05.26.
//

import DesignBook
import SwiftUI

/// Compact branded hero for setup screens — a gradient halo behind a glass disc
/// with an animated symbol, a title, and a live subtitle. Shared so the online
/// and nearby setup flows look consistent.
struct SetupHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            ZStack {
                HeroGlow(.setup)

                Circle()
                    .fill(DesignBook.Color.Background.card)
                    .frame(width: DesignBook.Size.heroDiscCompact, height: DesignBook.Size.heroDiscCompact)
                    .shadow(.medium)

                Image(systemName: systemImage)
                    .font(DesignBook.IconFont.large)
                    .foregroundStyle(DesignBook.Gradient.primary)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
            }
            .accessibilityHidden(true)
            .decorativeHeroSizing()

            Text(title)
                .font(DesignBook.Font.title1)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(DesignBook.Font.subheadline)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: subtitle)
        }
    }
}

// MARK: - Preview
#Preview {
    SetupHero(
        systemImage: "wifi",
        title: "Create a room",
        subtitle: "Set up the game and share the code with friends"
    )
    .padding()
    .setDefaultBackground()
}
