//
//  HatFillAnimation.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The hat on Fill the Hat, turned over like a magician's so its opening
/// faces up. Word chips fly in from either side on a 3D arc, tumbling and
/// shrinking with depth, and drop through the opening; the hat sways in
/// perspective and bobs as each lands. `labels` are what the chips say —
/// the players' names for typed words, sample words for picked ones. Still
/// under Reduce Motion, where the hat simply sits.
struct HatFillAnimation: View {
    let labels: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drops: [Drop] = []
    @State private var landings = 0

    private static let dropInterval: Duration = .milliseconds(700)
    /// Where the opening of the upturned hat sits, from the hero's center.
    fileprivate static let openingY: CGFloat = -30

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignBook.Gradient.primary)
                .frame(width: 176, height: 176)
                .blur(radius: 40)
                .opacity(DesignBook.Opacity.semiTransparent)

            Circle()
                .fill(DesignBook.Color.Background.card)
                .frame(width: 136, height: 136)
                .shadow(.large)

            // Under the hat, so a chip reaching the opening slips behind the brim.
            ForEach(drops) { drop in
                FlyingChip(drop: drop) { land(drop) }
            }

            hat
        }
        .frame(height: 196)
        .frame(maxWidth: .infinity)
        .task(id: labels) { await dropWords() }
        .accessibilityHidden(true)
    }
}

// MARK: - Hat
private extension HatFillAnimation {
    var hat: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                openingGlow
                Text(verbatim: "🎩")
                    .font(DesignBook.IconFont.emoji)
                    .rotationEffect(.degrees(180))
            }
            .phaseAnimator([1.0, 1.08, 1.0], trigger: landings) { hat, scale in
                hat.scaleEffect(scale, anchor: .bottom)
            } animation: { _ in
                .snappy(duration: 0.16)
            }
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : sin(time * 1.3) * 14),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : 10 + sin(time * 0.9) * 4),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.6
            )
        }
    }

    /// A soft glow over the opening that flares as a word drops in.
    var openingGlow: some View {
        Ellipse()
            .fill(DesignBook.Gradient.primary)
            .frame(width: 76, height: 18)
            .blur(radius: 8)
            .offset(y: Self.openingY - 4)
            .phaseAnimator([0.45, 0.95, 0.45], trigger: landings) { glow, opacity in
                glow.opacity(opacity)
            } animation: { _ in
                .easeOut(duration: 0.3)
            }
    }
}

// MARK: - Drops
private extension HatFillAnimation {
    struct Drop: Identifiable {
        let id = UUID()
        let label: String
        let start: CGPoint
        /// How far the chip is turned toward its side as it sets off, in
        /// degrees; it swings round to face the viewer on the way in.
        let yaw: Double
    }

    func dropWords() async {
        drops = []
        guard !reduceMotion, !labels.isEmpty else { return }
        var index = 0
        while !Task.isCancelled {
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            drops.append(Drop(
                label: labels[index % labels.count],
                start: CGPoint(x: side * .random(in: 90...140), y: .random(in: -70...(-10))),
                yaw: Double(side) * .random(in: 45...65)
            ))
            index += 1
            try? await Task.sleep(for: Self.dropInterval)
        }
    }

    func land(_ drop: Drop) {
        drops.removeAll { $0.id == drop.id }
        landings += 1
    }
}

// MARK: - Flying chip
/// One word flying from beside the hat into its opening.
private struct FlyingChip: View {
    let drop: HatFillAnimation.Drop
    let onLanded: () -> Void

    @State private var progress: Double = 0

    var body: some View {
        Text(drop.label)
            .font(DesignBook.Font.subheadlineSemibold)
            .foregroundStyle(DesignBook.Color.Text.accent)
            .lineLimit(1)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.vertical, DesignBook.Spacing.xs)
            .background(DesignBook.Color.Background.card, in: .capsule)
            .shadow(.medium)
            .modifier(ChipFlight(progress: progress, drop: drop))
            .onAppear {
                withAnimation(.timingCurve(0.35, 0, 0.6, 1, duration: 1.15)) {
                    progress = 1
                } completion: {
                    onLanded()
                }
            }
    }
}

/// Places a chip along its flight: a curve that rises before it falls into
/// the opening, a swing from side-on to facing the viewer, and a tilt back
/// and shrink as it drops away into the hat — readable all the way in.
/// Animatable, so every frame lands on the curve rather than on a straight
/// line between its ends.
private struct ChipFlight: ViewModifier, Animatable {
    var progress: Double
    let drop: HatFillAnimation.Drop

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let point = position(at: progress)
        let fall = progress * progress
        return content
            .rotation3DEffect(
                .degrees(drop.yaw * (1 - progress)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .rotation3DEffect(
                .degrees(60 * fall),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: 0.5
            )
            .scaleEffect(1 - 0.7 * fall)
            .opacity(opacity)
            .offset(x: point.x, y: point.y)
    }

    /// Fades in as it sets off and out as it passes the brim.
    private var opacity: Double {
        if progress < 0.08 { return progress / 0.08 }
        if progress > 0.9 { return (1 - progress) / 0.1 }
        return 1
    }

    /// A quadratic curve from the start, over a point above the hat, down
    /// into the opening.
    private func position(at time: Double) -> CGPoint {
        let start = drop.start
        let end = CGPoint(x: 0, y: HatFillAnimation.openingY)
        let control = CGPoint(x: start.x * 0.35, y: min(start.y, end.y) - 60)
        let rest = 1 - time
        let x = rest * rest * start.x + 2 * rest * time * control.x + time * time * end.x
        let y = rest * rest * start.y + 2 * rest * time * control.y + time * time * end.y
        return CGPoint(x: x, y: y)
    }
}
