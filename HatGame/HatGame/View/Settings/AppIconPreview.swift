//
//  AppIconPreview.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import DesignBook
import SwiftUI

/// The real icon artwork, masked like the Home Screen draws it: a continuous
/// rounded rectangle with a hairline edge. Each icon has a bundled 180 px
/// preview (`AppIconPreview-<icon>`) with light and dark variants, so the
/// preview matches what the Home Screen shows in each appearance.
struct AppIconPreview: View {
    /// The Home Screen icon mask's corner radius as a fraction of its side.
    private static let cornerRadiusRatio: CGFloat = 0.2237

    let icon: AppIcon
    let size: CGFloat

    var body: some View {
        Image("AppIconPreview-\(icon.rawValue)")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(iconShape)
            .overlay {
                iconShape
                    .strokeBorder(DesignBook.Color.Text.primary.opacity(0.12), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    private var iconShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * Self.cornerRadiusRatio, style: .continuous)
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
