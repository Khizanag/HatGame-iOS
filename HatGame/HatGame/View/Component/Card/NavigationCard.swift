//
//  NavigationCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

struct NavigationCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GameCard {
                HStack(spacing: DesignBook.Spacing.md) {
                    Image(systemName: icon)
                        .font(DesignBook.IconFont.extraLarge)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                        .frame(width: DesignBook.Size.largeIconSize, height: DesignBook.Size.largeIconSize)
                        .decorativeHeroSizing()

                    VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                        Text(title)
                            .font(DesignBook.Font.title3)
                            .foregroundStyle(DesignBook.Color.Text.primary)

                        Text(description)
                            .font(DesignBook.Font.subheadline)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
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
    .background(DesignBook.Color.Background.primary)
}
