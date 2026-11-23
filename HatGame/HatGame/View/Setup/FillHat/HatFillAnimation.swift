//
//  HatFillAnimation.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The hat on Fill the Hat, turned over like a magician's so its opening
/// faces up. Word chips fly in from either side on a 3D arc, tumbling and
/// shrinking with depth, and drop through the opening; the hat sways in
/// perspective and bobs as each lands. `labels` are what the chips say, in
/// order. Still under Reduce Motion, where the hat simply sits.
struct HatFillAnimation: View {
    let labels: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drops: [Drop] = []
    @State private var landings = 0

    private static let dropInterval: Duration = .milliseconds(700)

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

            UpturnedHat(landings: landings)
        }
        .frame(height: 196)
        .frame(maxWidth: .infinity)
        .task(id: labels) { await dropWords() }
        .accessibilityHidden(true)
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

    private static let flight = 1.1
    /// How far through the flight the chip is out of sight behind the brim;
    /// it counts as in from there, so the hat swells as it vanishes.
    private static let hiddenAt = 0.95

    var body: some View {
        Text(drop.label)
            .font(DesignBook.Font.subheadlineSemibold)
            .foregroundStyle(DesignBook.Color.Text.primary)
            .lineLimit(1)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.vertical, DesignBook.Spacing.xs)
            .background(DesignBook.Color.Background.card, in: .capsule)
            .shadow(.medium)
            .modifier(ChipFlight(progress: progress, drop: drop))
            .onAppear {
                // Picks up speed as it falls, so it drops through the brim in
                // the last instant.
                withAnimation(.timingCurve(0.4, 0, 0.8, 0.55, duration: Self.flight)) {
                    progress = 1
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(Self.flight * Self.hiddenAt))
                guard !Task.isCancelled else { return }
                onLanded()
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
            .perspectiveRotation(
                .degrees(drop.yaw * (1 - progress)),
                axis: RotationAxis(x: 0, y: 1),
                perspective: 0.5
            )
            .perspectiveRotation(
                .degrees(60 * fall),
                axis: RotationAxis(x: 1, y: 0),
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
        if progress > 0.95 { return (1 - progress) / 0.05 }
        return 1
    }

    /// A quadratic curve from the start, over a point above the hat, down
    /// into the opening.
    private func position(at time: Double) -> CGPoint {
        let start = drop.start
        let end = CGPoint(x: 0, y: UpturnedHat.openingY)
        let control = CGPoint(x: start.x * 0.35, y: min(start.y, end.y) - 60)
        let rest = 1 - time
        let x = rest * rest * start.x + 2 * rest * time * control.x + time * time * end.x
        let y = rest * rest * start.y + 2 * rest * time * control.y + time * time * end.y
        return CGPoint(x: x, y: y)
    }
}
