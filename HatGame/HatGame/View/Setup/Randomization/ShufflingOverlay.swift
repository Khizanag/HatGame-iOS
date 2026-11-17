//
//  ShufflingOverlay.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The dimmed spinning-hat overlay shown while the hat is shuffled. The
/// whole overlay is one button: a tap skips straight to the game.
struct ShufflingOverlay: View {
    let reduceMotion: Bool
    let onSkip: () -> Void

    @State private var rotationAngle: Double = 0

    var body: some View {
        Button(action: onSkip) {
            overlayContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(localized("randomization.shuffling.message")))
        .accessibilityHint(Text(localized("common.tapToSkip")))
        .accessibilityAddTraits(.isModal)
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
    var overlayContent: some View {
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

                    Text(localized("common.tapToSkip"))
                        .font(DesignBook.Font.footnote)
                        .foregroundStyle(DesignBook.Color.onGradient.opacity(DesignBook.Opacity.mostlyOpaque))
                        .padding(.top, DesignBook.Spacing.md)
                }
            }
        }
        .contentShape(.rect)
    }

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

    /// A glass disc floating over the dimmed screen.
    var disc: some View {
        Color.clear
            .frame(width: 128, height: 128)
            .glassSurface(in: .circle)
    }
}
