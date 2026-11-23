//
//  NavigationCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

/// A card that opens a mode or a screen, in Liquid Glass.
struct NavigationCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: icon)
                    .font(DesignBook.IconFont.extraLarge)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .frame(width: DesignBook.Size.largeIconSize, height: DesignBook.Size.largeIconSize)
                    .decorativeHeroSizing()

                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    Text(title)
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Text(description)
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.glassCard)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(description))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignBook.Spacing.md) {
        NavigationCard(
            icon: "app.gift.fill",
            title: "App Icon",
            description: "Choose your favorite app icon style"
        ) {}

        NavigationCard(
            icon: "slider.horizontal.3",
            title: "Defaults",
            description: "Configure default game settings"
        ) {}
    }
    .padding()
    .background(DesignBook.Gradient.brandBackdrop)
}
