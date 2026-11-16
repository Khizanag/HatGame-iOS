//
//  RevealedTeamCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The randomly picked starting team, revealed with its players.
struct RevealedTeamCard: View {
    let team: Team
    let isRevealed: Bool

    var body: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.lg) {
                trophyIcon
                    .decorativeHeroSizing()

                VStack(spacing: DesignBook.Spacing.sm) {
                    Text(localized("randomization.startingTeam.selected"))
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.secondary)

                    Text(team.name)
                        .font(DesignBook.Font.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .fontWeight(.bold)
                        .foregroundStyle(team.color)

                    Text(localized("randomization.startingTeam.goesFirst"))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                playersList
            }
            .padding(DesignBook.Spacing.lg)
        }
    }
}

// MARK: - RevealedTeamCard subviews
private extension RevealedTeamCard {
    var trophyIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [team.color.opacity(0.3), team.color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)

            Image(systemName: "trophy.fill")
                .font(DesignBook.IconFont.large)
                .foregroundStyle(team.color)
                .symbolEffect(.bounce, value: isRevealed)
        }
    }

    var playersList: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
            ForEach(team.players) { player in
                HStack(spacing: DesignBook.Spacing.sm) {
                    Circle()
                        .fill(team.color.opacity(0.3))
                        .frame(width: 8, height: 8)

                    Text(player.name)
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                }
            }
        }
        .padding(DesignBook.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignBook.Color.Background.secondary)
        .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
    }
}
