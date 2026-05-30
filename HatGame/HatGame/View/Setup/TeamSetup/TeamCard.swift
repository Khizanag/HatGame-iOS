//
//  TeamCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

struct TeamCard: View {
    let team: Team
    let playersPerTeam: Int

    var body: some View {
        GameCard {
            HStack(alignment: .top, spacing: DesignBook.Spacing.md) {
                ribbon
                VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                    header
                    playersList
                }
            }
        }
    }
}

// MARK: - Subviews
private extension TeamCard {
    var ribbon: some View {
        Capsule()
            .fill(team.color)
            .frame(width: DesignBook.Spacing.xs)
            .accessibilityHidden(true)
    }

    var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(team.name)
                .font(DesignBook.Font.headline)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .lineLimit(1)

            Spacer()

            Text(verbatim: "\(team.players.count)/\(playersPerTeam)")
                .font(DesignBook.Font.captionBold)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .monospacedDigit()
        }
    }

    var playersList: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            ForEach(team.players) { player in
                HStack(spacing: DesignBook.Spacing.sm) {
                    Circle()
                        .fill(team.color)
                        .frame(width: DesignBook.Size.dotMedium, height: DesignBook.Size.dotMedium)

                    Text(player.name)
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
            }
        }
    }
}
