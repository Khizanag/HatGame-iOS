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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DesignBook.Spacing.md) {
                preview

                VStack(spacing: DesignBook.Spacing.xs) {
                    Text(icon.title)
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                        .lineLimit(titleLineLimit, reservesSpace: true)
                        .minimumScaleFactor(0.8)

                    Text(icon.subtitle)
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .lineLimit(subtitleLineLimit, reservesSpace: true)
                }
                .multilineTextAlignment(.center)
            }
            .padding(DesignBook.Spacing.md)
            .frame(maxWidth: .infinity)
            .cardSurface()
            .overlay {
                RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? icon.displayColor : .clear, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointerHoverEffect()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(icon.title))
        .accessibilityValue(Text(icon.subtitle))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Subviews
private extension AppIconCard {
    /// The grid is one column at accessibility sizes, which gives the text
    /// room for more lines.
    var titleLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 3 : 1
    }

    var subtitleLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 4 : 2
    }

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
