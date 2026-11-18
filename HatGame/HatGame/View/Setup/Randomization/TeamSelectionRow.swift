//
//  TeamSelectionRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// A selectable team in the starting-team list.
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
                .foregroundStyle(isSelected ? DesignBook.Color.Text.accent : DesignBook.Color.Text.tertiary)
        }
        .padding(DesignBook.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                .fill(DesignBook.Color.Background.card)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                        .stroke(isSelected ? team.color : Color.clear, lineWidth: 2)
                }
        }
        .shadow(color: team.color.opacity(isSelected ? 0.45 : 0), radius: 14)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
