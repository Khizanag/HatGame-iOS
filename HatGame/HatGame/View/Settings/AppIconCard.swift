//
//  AppIconCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import DesignBook
import SwiftUI

/// A selectable app-icon option in the icon grid. Title and subtitle reserve
/// a fixed number of lines, so every card in a row has the same height and
/// long names truncate the same way.
struct AppIconCard: View {
    let icon: AppIcon
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DesignBook.Spacing.md) {
                preview

                VStack(spacing: DesignBook.Spacing.xs) {
                    Text(icon.title)
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(icon.subtitle)
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.glassCard(selection: isSelected ? icon.displayColor : nil, alignment: .center))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(icon.title))
        .accessibilityValue(Text(icon.subtitle))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Subviews
private extension AppIconCard {
    var preview: some View {
        ZStack(alignment: .topTrailing) {
            AppIconPreview(icon: icon, size: 100)

            if isSelected {
                AppIconSelectedBadge(color: icon.displayColor)
                    .offset(x: 8, y: -8)
            }
        }
    }
}
