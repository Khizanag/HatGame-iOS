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
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.secondary)

                    Text(team.name)
                        .font(DesignBook.Font.displayMedium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignBook.Color.teamText(for: team.color))

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

// MARK: - Flip transition
extension AnyTransition {
    /// The revealed team turns over into view like a card, in perspective.
    static var cardFlip: AnyTransition {
        .modifier(
            active: CardFlip(angle: -100, scale: 0.85, opacity: 0),
            identity: CardFlip(angle: 0, scale: 1, opacity: 1)
        )
    }
}

private struct CardFlip: ViewModifier {
    let angle: Double
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .perspectiveRotation(.degrees(angle), axis: RotationAxis(x: 0, y: 1), perspective: 0.45)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}
