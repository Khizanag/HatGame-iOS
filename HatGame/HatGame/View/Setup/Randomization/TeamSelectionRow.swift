//
//  TeamSelectionRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// A selectable team in the starting-team list: the label of a
/// `.glassCard(selection:)` button.
struct TeamSelectionRow: View {
    let team: Team
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            RoundedRectangle(cornerRadius: DesignBook.Size.smallCardCornerRadius)
                .fill(team.color)
                .frame(width: 8)

            VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                Text(team.name)
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                Text(localized("randomization.team.players \(team.players.count)"))
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(DesignBook.IconFont.medium)
                .foregroundStyle(isSelected ? DesignBook.Color.Text.accent : DesignBook.Color.Text.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
