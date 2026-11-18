//
//  GameHeaderBar.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import DesignBook
import SwiftUI

/// Compact header shown above the timer: the team name (tinted) and a live
/// badge with the points this turn has earned (guesses less skip penalties).
/// The round is the navigation title, so it isn't repeated here.
struct GameHeaderBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let team: Team
    let points: Int

    var body: some View {
        HStack(alignment: .center) {
            teamName
            Spacer()
            TurnScoreBadge(points: points, reduceMotion: reduceMotion)
        }
    }
}

// MARK: - Subviews
private extension GameHeaderBar {
    var teamName: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Circle()
                .fill(team.color)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(team.name)
                .font(DesignBook.Font.title1)
                .foregroundStyle(DesignBook.Color.teamText(for: team.color))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// Live "X points this turn" pill. Bounces when the count changes.
private struct TurnScoreBadge: View {
    let points: Int
    let reduceMotion: Bool

    /// Orange once skip penalties push the turn below zero.
    private var tint: Color {
        points < 0 ? DesignBook.Color.Status.warning : DesignBook.Color.Status.success
    }

    var body: some View {
        HStack(spacing: DesignBook.Spacing.xs) {
            Image(systemName: "checkmark.seal.fill")
                .font(DesignBook.Font.subheadlineSemibold)
            Text(points, format: .number)
                .font(DesignBook.Font.title1)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(tint)
        .padding(.horizontal, DesignBook.Spacing.md)
        .padding(.vertical, DesignBook.Spacing.sm)
        .background {
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay {
                    Capsule()
                        .strokeBorder(tint.opacity(0.4), lineWidth: 1)
                }
        }
        .animation(reduceMotion ? nil : DesignBook.Motion.bouncy, value: points)
        .accessibilityLabel(Text(localized("game.turn.points.accessibility \(points)")))
    }
}
