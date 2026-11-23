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
    /// Filled for the band the timer is in, an outline otherwise, so the
    /// mark reads by shape as well as by colour (constitution article 8).
    var indicator: some View {
        Image(systemName: isHighlighted ? "circle.fill" : "circle")
            .font(DesignBook.Font.caption2)
            .foregroundStyle(isHighlighted ? DesignBook.Color.Text.primary : DesignBook.Color.Text.tertiary)
            .contentTransition(.symbolEffect(.replace))
    }

    var label: some View {
        VStack(spacing: DesignBook.Spacing.xxs) {
            Text(title)
                .font(DesignBook.Font.subheadlineSemibold)
                .foregroundStyle(
                    isHighlighted
                    ? DesignBook.Color.Text.primary
                    : DesignBook.Color.Text.secondary
                )

            Text(range)
                .font(DesignBook.Font.subheadline)
                .foregroundStyle(
                    isHighlighted
                    ? DesignBook.Color.Text.secondary
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
