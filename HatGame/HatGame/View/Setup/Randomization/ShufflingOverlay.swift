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
                DesignBook.Color.scrim.ignoresSafeArea()

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
            HeroGlow(.shuffle, opacity: DesignBook.Opacity.strong)

            Color.clear
                .frame(width: DesignBook.Size.heroDisc, height: DesignBook.Size.heroDisc)
                .glassSurface(in: .circle)

            slips.layer(front: false)
            UpturnedHat(landings: slips.landings)
            slips.layer(front: true)
        }
        .frame(width: DesignBook.Size.shuffleStageWidth, height: DesignBook.Size.shuffleStageHeight)
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
                .frame(width: DesignBook.Size.shuffleProgressWidth)
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
/// they orbit the hat on a tilted ring, nearer ones larger; then each in
/// turn hops up off the ring and drops through the opening, out of sight
/// behind the brim, and the hat bobs as it goes in.
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

    /// How high a slip hops above the opening on its way in.
    private static let hop: CGFloat = 44

    /// Slips that have gone in so far; the hat bobs as each one does.
    var landings: Int {
        (0..<Self.count).filter { isInside($0) }.count
    }

    /// Whether a slip has dropped below the brim, out of sight: from then
    /// on it counts as in. Judged at the highest point its swing could put
    /// it, so it never pops back out as it spins.
    private func isInside(_ index: Int) -> Bool {
        let ownClose = fall(of: index)
        guard ownClose > 0.5 else { return false }
        let reach = CGFloat(1 - ownClose * ownClose)
        let radius = Self.radius * reach
        let scale = 0.35 + 0.65 * reach
        let highestTop = UpturnedHat.openingY - radius * 0.36 - 18 * reach - lift(ownClose)
            - Slip.height / 2 * scale
        return highestTop > UpturnedHat.brimTopY
    }

    /// Rises off the ring, then comes down into the opening, so it never
    /// crosses in front of the crown on the way in.
    private func lift(_ ownClose: Double) -> CGFloat {
        Self.hop * CGFloat(sin(.pi * ownClose))
    }

    /// How far one slip has spiralled from the ring into the opening, from
    /// zero to one. Each falls at its own moment as the ring closes.
    private func fall(of index: Int) -> Double {
        let share = Double(index) / Double(Self.count)
        return min(1, max(0, closing * 1.6 - share * 0.6))
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
        let ownClose = fall(of: index)
        let radius = Self.radius * CGFloat(1 - ownClose * ownClose)
        let depth = sin(angle)
        let reach = radius / Self.radius
        return Placement(
            offsetX: CGFloat(cos(angle)) * radius,
            offsetY: UpturnedHat.openingY + CGFloat(depth) * radius * 0.36 - 18 * reach - lift(ownClose),
            scale: (0.78 + 0.22 * CGFloat(depth + 1) / 2) * (0.35 + 0.65 * reach),
            spin: angle * 180 / .pi * 1.5,
            opacity: isInside(index) ? 0 : 1,
            // Behind the hat for the drop, so the brim swallows it.
            isFront: depth > 0 && ownClose < 0.5
        )
    }
}

/// A folded paper slip with a word on it, face hidden.
private struct Slip: View {
    static let height = DesignBook.Size.slipHeight

    var body: some View {
        RoundedRectangle(cornerRadius: DesignBook.Size.slipCornerRadius, style: .continuous)
            .fill(DesignBook.Color.Background.card)
            .frame(width: DesignBook.Size.slipWidth, height: Self.height)
            .overlay {
                VStack(spacing: DesignBook.Spacing.xs) {
                    Capsule().frame(width: 24, height: 2.5)
                    Capsule().frame(width: 16, height: 2.5)
                }
                .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            .shadow(.medium)
    }
}
