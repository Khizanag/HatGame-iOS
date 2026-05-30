//
//  CircularIconContainer.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 26.11.25.
//

import DesignBook
import SwiftUI

struct CircularIconContainer: View {
    let icon: String
    let size: CGFloat
    let iconSize: CGFloat?
    let color: Color
    let backgroundColor: Color?
    let gradientColors: [Color]?
    let hasShadow: Bool

    init(
        icon: String,
        size: CGFloat = DesignBook.Size.cardLarge,
        iconSize: CGFloat? = nil,
        color: Color = DesignBook.Color.Text.primary,
        backgroundColor: Color? = nil,
        gradientColors: [Color]? = nil,
        hasShadow: Bool = false
    ) {
        self.icon = icon
        self.size = size
        self.iconSize = iconSize
        self.color = color
        self.backgroundColor = backgroundColor
        self.gradientColors = gradientColors
        self.hasShadow = hasShadow
    }

    var body: some View {
        ZStack {
            if let gradientColors = gradientColors {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
            } else if let backgroundColor = backgroundColor {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
            }

            Image(systemName: icon)
                // Icon size scales with the container's `size` parameter, so it is intentionally dynamic.
                // swiftlint:disable:next no_inline_font
                .font(.system(size: calculatedIconSize))
                .foregroundStyle(color)
        }
        .shadow(
            color: hasShadow ? .black.opacity(DesignBook.Opacity.highlight) : .clear,
            radius: hasShadow ? 8 : 0,
            x: 0,
            y: hasShadow ? 4 : 0
        )
    }

    private var calculatedIconSize: CGFloat {
        iconSize ?? (size * 0.5)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignBook.Spacing.lg) {
        // Simple background
        CircularIconContainer(
            icon: "star.fill",
            size: DesignBook.Size.cardLarge,
            color: .white,
            backgroundColor: .blue
        )

        // Gradient background
        CircularIconContainer(
            icon: "flame.fill",
            size: DesignBook.Size.cardMassive,
            color: .white,
            gradientColors: [.orange, .pink],
            hasShadow: true
        )

        // No background
        CircularIconContainer(
            icon: "checkmark",
            size: DesignBook.Size.cardMedium,
            color: .green
        )

        // Custom icon size
        CircularIconContainer(
            icon: "sparkles",
            size: DesignBook.Size.cardLarge,
            iconSize: 35,
            color: .white,
            backgroundColor: .purple,
            hasShadow: true
        )
    }
    .padding()
}
