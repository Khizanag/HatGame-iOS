//
//  HatFillAnimation.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The hat on Fill the Hat: word chips drop into it one after another, and
/// it bobs as each lands. `labels` are what the chips say — the players'
/// names for typed words, sample words for picked ones. Still under Reduce
/// Motion, where the hat simply sits.
struct HatFillAnimation: View {
    let labels: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drops: [Drop] = []
    @State private var landings = 0

    private static let dropInterval: Duration = .milliseconds(850)

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

            ForEach(drops) { drop in
                FallingChip(drop: drop) { land(drop) }
            }

            Text(verbatim: "🎩")
                .font(DesignBook.IconFont.emoji)
                .phaseAnimator([1.0, 1.1, 1.0], trigger: landings) { hat, scale in
                    hat.scaleEffect(scale, anchor: .bottom)
                } animation: { _ in
                    .snappy(duration: 0.16)
                }
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
        let startX: CGFloat
        let tilt: Double
    }

    func dropWords() async {
        drops = []
        guard !reduceMotion, !labels.isEmpty else { return }
        var index = 0
        while !Task.isCancelled {
            drops.append(Drop(
                label: labels[index % labels.count],
                startX: .random(in: -70...70),
                tilt: .random(in: -14...14)
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

// MARK: - Falling chip
/// One word falling from above the hat into its crown, shrinking and
/// fading as it goes in.
private struct FallingChip: View {
    let drop: HatFillAnimation.Drop
    let onLanded: () -> Void

    @State private var hasLanded = false

    var body: some View {
        Text(drop.label)
            .font(DesignBook.Font.subheadlineSemibold)
            .foregroundStyle(DesignBook.Color.Text.accent)
            .lineLimit(1)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.vertical, DesignBook.Spacing.xs)
            .background(DesignBook.Color.Background.card, in: .capsule)
            .shadow(.medium)
            .rotationEffect(.degrees(hasLanded ? 0 : drop.tilt))
            .scaleEffect(hasLanded ? 0.3 : 1)
            .opacity(hasLanded ? 0 : 1)
            .offset(x: hasLanded ? 0 : drop.startX, y: hasLanded ? -6 : -96)
            .onAppear {
                withAnimation(.easeIn(duration: 0.95)) {
                    hasLanded = true
                } completion: {
                    onLanded()
                }
            }
    }
}
