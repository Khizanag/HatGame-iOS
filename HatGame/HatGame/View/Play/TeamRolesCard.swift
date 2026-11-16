//
//  TeamRolesCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The team's locked roles for this turn: who explains and who guesses.
struct TeamRolesCard: View {
    let team: Team
    let explainer: Player?
    let guessers: [Player]

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack {
                    Text(localized("game.nextTeam.teamRoles"))
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Spacer()

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                }

                VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                    if let explainer {
                        roleSection(
                            icon: "person.wave.2.fill",
                            iconColor: team.color,
                            label: "game.nextTeam.role.explaining",
                            content: { explainerRow(explainer) }
                        )
                    }

                    if !guessers.isEmpty {
                        roleSection(
                            icon: "lightbulb.fill",
                            iconColor: DesignBook.Color.Text.accent,
                            label: "game.nextTeam.role.guessing",
                            content: { guessersList }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Subviews
private extension TeamRolesCard {
    func roleSection<Content: View>(
        icon: String,
        iconColor: Color,
        label: String.LocalizationValue,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            HStack(spacing: DesignBook.Spacing.xs) {
                Image(systemName: icon)
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(iconColor)

                Text(localized(label))
                    .font(DesignBook.Font.caption1Semibold)
                    .uppercaseLabel()
                    .tracking(1.2)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            content()
        }
    }

    func explainerRow(_ explainer: Player) -> some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Circle()
                .fill(team.color.opacity(DesignBook.Opacity.semiTransparent))
                .frame(width: DesignBook.Size.dotSmall, height: DesignBook.Size.dotSmall)

            Text(explainer.name)
                .font(DesignBook.Font.bodySemibold)
                .foregroundStyle(DesignBook.Color.teamText(for: team.color))
        }
        .padding(DesignBook.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(team.color.opacity(DesignBook.Opacity.light))
        .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
    }

    var guessersList: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
            ForEach(guessers) { guesser in
                HStack(spacing: DesignBook.Spacing.sm) {
                    Circle()
                        .fill(DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.medium))
                        .frame(width: DesignBook.Size.dotSmall, height: DesignBook.Size.dotSmall)

                    Text(guesser.name)
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                }
                .padding(.horizontal, DesignBook.Spacing.sm)
                .padding(.vertical, DesignBook.Spacing.xs)
            }
        }
        .padding(DesignBook.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignBook.Color.Background.secondary)
        .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
    }
}
