//
//  LegendTag.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

/// Read-only category indicator used under sliders to show which bucket the
/// current value falls into. Visually flat (no chip background) so it is not
/// confused with a tappable control.
struct LegendTag: View {
    let title: String
    let range: String
    let isHighlighted: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DesignBook.Spacing.xs) {
            indicator
            label
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignBook.Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }
}

// MARK: - Sub-views
private extension LegendTag {
    var indicator: some View {
        Circle()
            .fill(
                isHighlighted
                ? DesignBook.Color.Text.accent
                : DesignBook.Color.Text.tertiary.opacity(0.25)
            )
            .frame(width: 6, height: 6)
            .scaleEffect(isHighlighted ? 1.25 : 1)
            .animation(reduceMotion ? nil : DesignBook.Motion.snappy, value: isHighlighted)
    }

    var label: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(DesignBook.Font.captionBold)
                .foregroundStyle(
                    isHighlighted
                    ? DesignBook.Color.Text.accent
                    : DesignBook.Color.Text.secondary
                )

            Text(range)
                .font(DesignBook.Font.caption)
                .foregroundStyle(
                    isHighlighted
                    ? DesignBook.Color.Text.accent.opacity(0.8)
                    : DesignBook.Color.Text.tertiary
                )
                .monospacedDigit()
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Preview
#Preview {
    HStack(spacing: DesignBook.Spacing.md) {
        LegendTag(title: "Lightning", range: "5-30s", isHighlighted: false)
        LegendTag(title: "Classic", range: "60s", isHighlighted: true)
        LegendTag(title: "Marathon", range: "90-120s", isHighlighted: false)
    }
    .padding()
}
