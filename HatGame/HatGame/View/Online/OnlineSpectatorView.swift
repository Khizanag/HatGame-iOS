//
//  OnlineSpectatorView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import DesignBook
import Networking
import SwiftUI

/// Shown to every non-explainer during the Playing phase:
/// - same-team guessers see "Listen to your teammate!" and a team-tinted hero
/// - opposing-team spectators see "Team X is playing" with the same theme
/// Neither role sees the actual word. The timer is driven entirely by
/// `gameState.timerStartedAt` so all devices land on the same countdown.
struct OnlineSpectatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let team: OnlineTeam
    let explainerName: String
    let isOwnTeam: Bool
    let remainingSeconds: Int
    let totalSeconds: Int
    let teamScore: Int
    let totalWords: Int
    let remainingWords: Int

    private var tint: Color {
        team.color
    }

    private var passedWords: Int { totalWords - remainingWords }

    var body: some View {
        CenteredScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                roleBanner
                CircularTimerView(
                    remainingSeconds: remainingSeconds,
                    totalSeconds: totalSeconds,
                    isPaused: false,
                    tint: tint
                )
                .frame(width: 168, height: 168)

                scoreChip
                instructionCard

                GameProgressFooter(passed: passedWords, total: totalWords, tint: tint)
            }
            .padding(.top, DesignBook.Spacing.lg)
            .paddingHorizontalDefault()
        }
    }
}

// MARK: - Subviews
private extension OnlineSpectatorView {
    var roleBanner: some View {
        VStack(spacing: 4) {
            Text(localized(isOwnTeam ? "onlineSpectator.yourTurn" : "onlineSpectator.othersTurn"))
                .font(DesignBook.Font.caption1Semibold)
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(DesignBook.Color.Text.tertiary)

            HStack(spacing: DesignBook.Spacing.sm) {
                Circle().fill(tint).frame(width: 10, height: 10)
                Text(team.name)
                    .font(DesignBook.Font.title1)
                    .foregroundStyle(DesignBook.Color.teamText(for: tint))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    var scoreChip: some View {
        HStack(spacing: DesignBook.Spacing.xs) {
            Image(systemName: "checkmark.seal.fill")
                .font(DesignBook.Font.subheadlineSemibold)
            Text(verbatim: "\(teamScore)")
                .font(DesignBook.Font.title1)
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
                    Capsule().strokeBorder(DesignBook.Color.Status.success.opacity(0.4), lineWidth: 1)
                }
        }
        .animation(reduceMotion ? nil : DesignBook.Motion.bouncy, value: teamScore)
        .accessibilityLabel(Text(localized("onlineSpectator.score.accessibility \(teamScore)")))
    }

    var instructionCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: isOwnTeam ? "ear.fill" : "eye.fill")
                    .font(DesignBook.IconFont.sized(38, relativeTo: .largeTitle))
                    .decorativeHeroSizing()
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)

                Text(localized(isOwnTeam ? "onlineSpectator.listen" : "onlineSpectator.watching"))
                    .font(DesignBook.Font.title1)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .multilineTextAlignment(.center)

                Text(String(format: localized("onlineSpectator.explainerLabel"), explainerName))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(DesignBook.Spacing.md)
        }
    }
}
