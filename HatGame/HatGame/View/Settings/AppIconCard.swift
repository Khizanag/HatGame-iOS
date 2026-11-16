//
//  AppIconCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import DesignBook
import SwiftUI

/// A selectable app-icon option in the icon grid.
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
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Text(icon.subtitle)
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DesignBook.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(DesignBook.Color.Background.card)
            .clipShape(.rect(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                    .stroke(isSelected ? icon.displayColor : .clear, lineWidth: isSelected ? 2 : 0)
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(Text(icon.title))
    }
}

// MARK: - Subviews
private extension AppIconCard {
    var preview: some View {
        ZStack(alignment: .topTrailing) {
            AppIconPreview(icon: icon, size: 100, symbolSize: 40)

            if isSelected {
                AppIconSelectedBadge(color: icon.displayColor)
                    .offset(x: 8, y: -8)
            }
        }
    }
}
