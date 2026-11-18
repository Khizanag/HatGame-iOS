//
//  UpturnedHat.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The hat turned over like a magician's, its opening up: it sways in
/// perspective, a glow sits over the opening, and both bob each time
/// `landings` changes — a word going in. Still under Reduce Motion.
struct UpturnedHat: View {
    var landings = 0

    /// Where the opening sits, from the hat's center.
    static let openingY: CGFloat = -26
    /// The top edge of the brim: anything behind the hat and below this is
    /// out of sight inside it.
    static let brimTopY: CGFloat = openingY - 7
    /// The flipped emoji draws above the middle of its text box; this
    /// drops it so the hat sits centered on whatever is behind it.
    private static let glyphCentering: CGFloat = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                openingGlow
                Text(verbatim: "🎩")
                    .font(DesignBook.IconFont.emoji)
                    .rotationEffect(.degrees(180))
                    .offset(y: Self.glyphCentering)
            }
            // Swells the instant a word goes in, then settles with a bounce.
            .phaseAnimator([1.0, 1.1], trigger: landings) { hat, scale in
                hat.scaleEffect(scale, anchor: .bottom)
            } animation: { scale in
                scale > 1 ? .easeOut(duration: 0.07) : .spring(duration: 0.3, bounce: 0.45)
            }
            .perspectiveRotation(
                .degrees(reduceMotion ? 0 : sin(time * 1.3) * 14),
                axis: RotationAxis(x: 0, y: 1),
                perspective: 0.6
            )
            .perspectiveRotation(
                .degrees(reduceMotion ? 0 : 10 + sin(time * 0.9) * 4),
                axis: RotationAxis(x: 1, y: 0),
                perspective: 0.6
            )
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Glow
private extension UpturnedHat {
    /// A soft glow over the opening that flares as a word drops in.
    var openingGlow: some View {
        Ellipse()
            .fill(DesignBook.Gradient.primary)
            .frame(width: 76, height: 18)
            .blur(radius: 8)
            .offset(y: Self.openingY - 4)
            .phaseAnimator([0.45, 0.95], trigger: landings) { glow, opacity in
                glow.opacity(opacity)
            } animation: { opacity in
                opacity > 0.5 ? .easeOut(duration: 0.07) : .easeIn(duration: 0.35)
            }
    }
}
