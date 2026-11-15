//
//  RandomizationHeaderCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The pulsing header card that opens the randomization screen.
struct RandomizationHeaderCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                CircularIconContainer(
                    icon: "sparkles",
                    size: DesignBook.Size.cardLarge,
                    iconSize: 35,
                    color: DesignBook.Color.Text.accent,
                    gradientColors: [
                        DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.highlight),
                        DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.veryLight),
                    ]
                )
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)

                VStack(spacing: DesignBook.Spacing.xs) {
                    Text(localized("randomization.header.title"))
                        .font(DesignBook.Font.title2)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Text(localized("randomization.header.subtitle"))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DesignBook.Spacing.md)
        }
    }
}
