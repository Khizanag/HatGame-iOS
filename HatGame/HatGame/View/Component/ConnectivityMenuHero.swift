//
//  ConnectivityMenuHero.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import DesignBook
import SwiftUI

/// Shared hero treatment used at the top of connectivity entry screens
/// (`OnlineMenuView`, `LocalMenuView`). A gradient halo behind a glass-card
/// disc with a symbol on top, animated by either an iterating variable
/// color (live wireless feel) or a soft scale pulse (steady state).
struct ConnectivityMenuHero: View {
    enum IconAnimation {
        /// Iterating variable color — for active/wireless states.
        case iterating
        /// Soft scale pulse — for steady "ready to play" states.
        case pulse
    }

    let symbol: String
    let title: String.LocalizationValue
    let description: String.LocalizationValue
    let animation: IconAnimation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing: Bool = false

    var body: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DesignBook.Gradient.primary)
                    .frame(width: 156, height: 156)
                    .blur(radius: 36)
                    .opacity(0.55)

                Circle()
                    .fill(DesignBook.Color.Background.card)
                    .frame(width: 136, height: 136)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        DesignBook.Color.Text.accent.opacity(0.4),
                                        DesignBook.Color.Text.accent.opacity(0.0),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(.large)

                Image(systemName: symbol)
                    .font(DesignBook.IconFont.display)
                    .foregroundStyle(DesignBook.Gradient.primary)
                    .modifier(
                        IconAnimationModifier(animation: animation, isPulsing: isPulsing, reduceMotion: reduceMotion)
                    )
            }
            .accessibilityHidden(true)
            .decorativeHeroSizing()

            VStack(spacing: DesignBook.Spacing.xs) {
                Text(localized(title))
                    .font(DesignBook.Font.largeTitle)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                Text(localized(description))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignBook.Spacing.lg)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct IconAnimationModifier: ViewModifier {
    let animation: ConnectivityMenuHero.IconAnimation
    let isPulsing: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        switch animation {
        case .iterating:
            content
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                .scaleEffect(reduceMotion ? 1.0 : (isPulsing ? 1.04 : 0.96))
        case .pulse:
            content.scaleEffect(reduceMotion ? 1.0 : (isPulsing ? 1.04 : 0.96))
        }
    }
}
