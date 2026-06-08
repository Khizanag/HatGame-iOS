//
//  GameHeaderBar.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import DesignBook
import SwiftUI

/// Compact header shown above the timer: round name (caps), team name (tinted),
/// and a live badge with the number of words guessed this turn.
struct GameHeaderBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let round: GameRound
    let team: Team
    let guessedCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            roundAndTeam
            Spacer()
            TurnScoreBadge(count: guessedCount, reduceMotion: reduceMotion)
        }
    }
}

// MARK: - Subviews
private extension GameHeaderBar {
    var roundAndTeam: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(round.title.uppercased())
                .font(DesignBook.Font.smallCaption)
                .tracking(1.5)
                .foregroundStyle(DesignBook.Color.Text.tertiary)

            HStack(spacing: DesignBook.Spacing.sm) {
                Circle()
                    .fill(team.color)
                    .frame(width: 10, height: 10)
                Text(team.name)
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(team.color)
                    .lineLimit(1)
            }
        }
    }
}

/// Live "X words guessed this turn" pill. Bounces when the count changes.
private struct TurnScoreBadge: View {
    let count: Int
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: DesignBook.Spacing.xs) {
            Image(systemName: "checkmark.seal.fill")
                .font(DesignBook.Font.captionBold)
            Text(verbatim: "\(count)")
                .font(DesignBook.Font.title3)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(DesignBook.Color.Status.success)
        .padding(.horizontal, DesignBook.Spacing.md)
        .padding(.vertical, DesignBook.Spacing.sm)
        .background {
            Capsule()
                .fill(DesignBook.Color.Status.success.opacity(0.12))
                .overlay {
                    Capsule()
                        .strokeBorder(DesignBook.Color.Status.success.opacity(0.4), lineWidth: 1)
                }
        }
        .animation(reduceMotion ? nil : DesignBook.Motion.bouncy, value: count)
        .accessibilityLabel(Text(localized("game.turn.score.accessibility \(count)")))
    }
}
