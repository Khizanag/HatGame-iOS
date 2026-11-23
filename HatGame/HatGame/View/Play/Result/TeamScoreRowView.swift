//
//  TeamScoreRowView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.25.
//

import DesignBook
import SwiftUI

struct TeamScoreRowView: View {
    let name: String
    let color: Color
    let rank: Int
    let score: Int
    let isWinner: Bool

    @ScaledMetric(relativeTo: .subheadline) private var rankBadgeSize: CGFloat = 32

    var body: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            rankBadge
            indicator
            nameView
            Spacer()
            scoreView
        }
        .padding(.horizontal, DesignBook.Spacing.md)
        .padding(.vertical, DesignBook.Spacing.sm + DesignBook.Spacing.xxs)
        .background {
            RoundedRectangle(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous)
                .fill(rowBackgroundColor)
                .overlay {
                    if isWinner {
                        RoundedRectangle(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous)
                            .strokeBorder(
                                color.opacity(DesignBook.Opacity.outline),
                                lineWidth: DesignBook.Size.strokeRegular
                            )
                    }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Initializers
extension TeamScoreRowView {
    /// Convenience for the local game, which has a `Team` with a `Color`.
    init(team: Team, rank: Int, score: Int, isWinner: Bool) {
        self.init(name: team.name, color: team.color, rank: rank, score: score, isWinner: isWinner)
    }
}

// MARK: - Components
private extension TeamScoreRowView {
    var rankBadge: some View {
        ZStack {
            Circle()
                .fill(rankBackgroundColor)
                .frame(width: rankBadgeSize, height: rankBadgeSize)

            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(DesignBook.Font.subheadlineSemibold)
                    .foregroundStyle(rankForegroundColor)
            } else {
                Text(verbatim: "\(rank)")
                    .font(DesignBook.Font.subheadlineSemibold)
                    .foregroundStyle(rankForegroundColor)
                    .monospacedDigit()
            }
        }
    }

    var indicator: some View {
        Circle()
            .fill(color)
            .frame(width: DesignBook.Size.dotRegular, height: DesignBook.Size.dotRegular)
    }

    var nameView: some View {
        Text(name)
            .font(DesignBook.Font.title3)
            .foregroundStyle(DesignBook.Color.Text.primary)
            .lineLimit(2)
    }

    var scoreView: some View {
        AnimatedScoreText(
            value: score,
            font: DesignBook.Font.title1,
            color: isWinner ? DesignBook.Color.teamText(for: color) : DesignBook.Color.Text.secondary,
            duration: DesignBook.Motion.scoreCountShort
        )
    }

    var rowBackgroundColor: Color {
        isWinner ? color.opacity(DesignBook.Opacity.light) : DesignBook.Color.Background.secondary
    }

    var rankBackgroundColor: Color {
        switch rank {
        case 1: return DesignBook.Color.opaque(color)
        case 2: return DesignBook.Color.Text.tertiary.opacity(DesignBook.Opacity.disabled)
        case 3: return DesignBook.Color.Text.tertiary.opacity(DesignBook.Opacity.soft)
        default: return DesignBook.Color.Background.secondary
        }
    }

    var rankForegroundColor: Color {
        rank == 1 ? DesignBook.Color.onAccent(for: color) : DesignBook.Color.Text.primary
    }

    var accessibilityLabel: Text {
        Text(localized("game.results.teamScore.accessibility \(name) \(rank) \(score)"))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignBook.Spacing.md) {
        TeamScoreRowView(team: Team(name: "Team 1", color: .blue), rank: 1, score: 25, isWinner: true)
        TeamScoreRowView(team: Team(name: "Team 2", color: .red), rank: 2, score: 20, isWinner: false)
        TeamScoreRowView(name: "Team 3", color: .green, rank: 3, score: 15, isWinner: false)
    }
    .padding()
    .setDefaultBackground()
}
