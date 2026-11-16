//
//  ShufflingOverlay.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The dimmed spinning-hat overlay shown while the hat is shuffled.
struct ShufflingOverlay: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let reduceMotion: Bool

    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: DesignBook.Spacing.xl) {
                hatBadge
                    .decorativeHeroSizing()
                    .accessibilityHidden(true)

                VStack(spacing: DesignBook.Spacing.sm) {
                    Text(localized("randomization.shuffling.message"))
                        .font(DesignBook.Font.displaySmall)
                        .foregroundStyle(DesignBook.Color.onGradient)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)

                    ProgressDotIndicator(
                        count: 3,
                        currentIndex: 1,
                        dotSize: DesignBook.Size.dotMedium,
                        spacing: 4,
                        completedColor: DesignBook.Color.onGradient.opacity(DesignBook.Opacity.mostlyOpaque),
                        currentColor: DesignBook.Color.onGradient.opacity(DesignBook.Opacity.mostlyOpaque),
                        pendingColor: DesignBook.Color.onGradient.opacity(DesignBook.Opacity.mostlyOpaque)
                    )
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - ShufflingOverlay subviews
private extension ShufflingOverlay {
    var hatBadge: some View {
        ZStack {
            Circle()
                .fill(DesignBook.Gradient.primary)
                .frame(width: 144, height: 144)
                .blur(radius: 24)
                .opacity(0.7)

            disc

            Text(verbatim: "🎩")
                .font(DesignBook.IconFont.emoji)
                .rotation3DEffect(.degrees(rotationAngle), axis: (x: 0.2, y: 1.0, z: 0.0))
        }
    }

    var disc: some View {
        ZStack {
            if reduceTransparency {
                Circle().fill(DesignBook.Color.Background.card)
            } else {
                Circle().fill(.thinMaterial)
            }
        }
        .frame(width: 128, height: 128)
        .overlay {
            Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 12)
    }
}
