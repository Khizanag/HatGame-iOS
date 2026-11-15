//
//  AppIconPreview.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import DesignBook
import SwiftUI

/// Square gradient icon preview with the symbol centered on top.
struct AppIconPreview: View {
    let icon: AppIcon
    let size: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: icon.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
            .shadow(color: icon.displayColor.opacity(0.3), radius: 8, x: 0, y: 4)

            Image(systemName: icon.iconSymbol)
                .font(DesignBook.IconFont.sized(symbolSize))
                .foregroundStyle(DesignBook.Color.onGradient)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
        .decorativeHeroSizing()
    }
}

// MARK: - Selected badge
/// The check badge pinned to a selected icon preview.
struct AppIconSelectedBadge: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignBook.Color.onGradient)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Image(systemName: "checkmark.circle.fill")
                .font(DesignBook.IconFont.medium)
                .foregroundStyle(color)
        }
        .decorativeHeroSizing()
    }
}
