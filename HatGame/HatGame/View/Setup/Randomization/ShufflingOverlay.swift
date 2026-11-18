//
//  ShufflingOverlay.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

/// Covers the screen while the hat is shuffled before the first turn:
/// blank word slips swirl around the upturned hat in 3D, then spiral in
/// through its opening as the shuffle ends. The slips stay blank so no
/// one's words show. A tap anywhere skips ahead.
struct ShufflingOverlay: View {
    let reduceMotion: Bool
    /// How long the shuffle runs before the game starts.
    let duration: Double
    let onSkip: () -> Void

    @State private var startDate = Date.now

    var body: some View {
        Button(action: onSkip) {
            overlayContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(localized("randomization.shuffling.message")))
        .accessibilityHint(Text(localized("common.tapToSkip")))
        .accessibilityAddTraits(.isModal)
        .onAppear { startDate = .now }
    }
}

// MARK: - Layout
private extension ShufflingOverlay {
    var overlayContent: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let progress = reduceMotion ? 1 : min(1, elapsed / max(duration, 0.1))
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()

                VStack(spacing: DesignBook.Spacing.xl) {
                    hatStage(elapsed: elapsed, progress: progress)
                        .decorativeHeroSizing()
                        .accessibilityHidden(true)
                    caption(progress: progress)
                }
            }
            .contentShape(.rect)
        }
    }

    func hatStage(elapsed: Double, progress: Double) -> some View {
        let slips = SlipSwirl(elapsed: elapsed, progress: progress, isActive: !reduceMotion)
        return ZStack {
            Circle()
                .fill(DesignBook.Gradient.primary)
                .frame(width: 168, height: 168)
                .blur(radius: 30)
                .opacity(0.7)

            Color.clear
                .frame(width: 136, height: 136)
                .glassSurface(in: .circle)

            slips.layer(front: false)
            UpturnedHat(landings: slips.landings)
            slips.layer(front: true)
        }
        .frame(width: 300, height: 240)
    }

    func caption(progress: Double) -> some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            Text(localized("randomization.shuffling.message"))
                .font(DesignBook.Font.displaySmall)
                .foregroundStyle(DesignBook.Color.onGradient)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(DesignBook.Color.onGradient)
                .frame(width: 160)
                .opacity(reduceMotion ? 0 : 1)

            Text(localized("common.tapToSkip"))
                .font(DesignBook.Font.footnote)
                .foregroundStyle(DesignBook.Color.onGradient.opacity(DesignBook.Opacity.mostlyOpaque))
                .padding(.top, DesignBook.Spacing.md)
        }
        .paddingHorizontalDefault()
    }
}

// MARK: - Slip swirl
/// Where every slip is at one moment of the shuffle. For the first part
/// they orbit the hat on a tilted ring, nearer ones larger; then the ring
/// tightens into the opening and each slip that reaches it goes in.
private struct SlipSwirl {
    let elapsed: Double
    let progress: Double
    let isActive: Bool

    static let count = 10
    private static let radius: CGFloat = 122
    /// When the ring starts closing in, as a fraction of the shuffle.
    private static let closeStart = 0.5

    /// How far the ring has closed, from zero to one.
    private var closing: Double {
        max(0, (progress - Self.closeStart) / (1 - Self.closeStart))
    }

    /// Slips that have gone in so far; the hat bobs as this climbs.
    var landings: Int {
        Int(closing * Double(Self.count))
    }

    @ViewBuilder
    func layer(front: Bool) -> some View {
        if isActive {
            ZStack {
                ForEach(0..<Self.count, id: \.self) { index in
                    let slip = place(index)
                    if slip.isFront == front, slip.opacity > 0 {
                        Slip()
                            .perspectiveRotation(.degrees(slip.spin), axis: RotationAxis(x: 0.2, y: 1))
                            .scaleEffect(slip.scale)
                            .opacity(slip.opacity)
                            .offset(x: slip.offsetX, y: slip.offsetY)
                    }
                }
            }
        }
    }

    private struct Placement {
        let offsetX: CGFloat
        let offsetY: CGFloat
        let scale: CGFloat
        let spin: Double
        let opacity: Double
        let isFront: Bool
    }

    private func place(_ index: Int) -> Placement {
        let share = Double(index) / Double(Self.count)
        // Speeds up as the shuffle goes on, like a hand stirring faster.
        let angle = elapsed * (2.2 + 2.4 * progress) + share * 2 * .pi
        // Each slip falls in at its own moment as the ring closes.
        let ownClose = min(1, max(0, closing * 1.6 - share * 0.6))
        let radius = Self.radius * CGFloat(1 - ownClose * ownClose)
        let depth = sin(angle)
        let reach = radius / Self.radius
        return Placement(
            offsetX: CGFloat(cos(angle)) * radius,
            offsetY: UpturnedHat.openingY + CGFloat(depth) * radius * 0.36 - 18 * reach,
            scale: (0.78 + 0.22 * CGFloat(depth + 1) / 2) * (0.35 + 0.65 * reach),
            spin: angle * 180 / .pi * 1.5,
            opacity: ownClose >= 1 ? 0 : min(1, Double(reach) * 4),
            isFront: depth > 0 && reach > 0.25
        )
    }
}

/// A folded paper slip with a word on it, face hidden.
private struct Slip: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(DesignBook.Color.Background.card)
            .frame(width: 40, height: 26)
            .overlay {
                VStack(spacing: 4) {
                    Capsule().frame(width: 24, height: 2.5)
                    Capsule().frame(width: 16, height: 2.5)
                }
                .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            .shadow(.medium)
    }
}
