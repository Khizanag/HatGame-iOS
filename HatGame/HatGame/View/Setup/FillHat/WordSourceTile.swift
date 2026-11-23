//
//  WordSourceTile.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// One of the two ways to fill the hat. A choice, not a link: selecting it
/// rings the tile and fills its symbol, and Continue acts on the choice.
struct WordSourceTile: View {
    let icon: String
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.glassCard(selection: isSelected ? DesignBook.Color.Text.accent : nil))
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(detail))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Layout
private extension WordSourceTile {
    var label: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .symbolVariant(isSelected ? .fill : .none)
                    .font(DesignBook.IconFont.medium)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .symbolEffect(.bounce, options: .nonRepeating, value: isSelected)
                Spacer(minLength: DesignBook.Spacing.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DesignBook.IconFont.small)
                    .foregroundStyle(isSelected ? DesignBook.Color.Text.accent : DesignBook.Color.Text.primary)
                    .contentTransition(.symbolEffect(.replace))
            }

            Text(title)
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(DesignBook.Font.subheadline)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
