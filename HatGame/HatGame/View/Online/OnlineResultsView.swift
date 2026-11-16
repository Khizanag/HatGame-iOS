//
//  OnlineResultsView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct OnlineResultsView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(RoomManager.self) private var roomManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasCelebrated: Bool = false

    private var teams: [OnlineTeam] { roomManager.room?.teams ?? [] }
    private var gameState: OnlineGameState? { roomManager.room?.gameState }

    private var sortedTeams: [(team: OnlineTeam, score: Int)] {
        teams.map { team in
            (team: team, score: gameState?.getTotalScore(for: team.id) ?? 0)
        }
        .sorted { $0.score > $1.score }
    }

    private var winners: [OnlineTeam] {
        guard let topScore = sortedTeams.first?.score else { return [] }
        return sortedTeams.filter { $0.score == topScore }.map(\.team)
    }

    var body: some View {
        content
            .navigationTitle(localized("onlineResults.title"))
            .setDefaultStyle()
            .overlay {
                if hasCelebrated {
                    ConfettiView(isActive: true).ignoresSafeArea().allowsHitTesting(false)
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(180))
                hasCelebrated = true
            }
            .onChange(of: hasCelebrated) { _, celebrated in
                if celebrated { DesignBook.Haptics.success() }
            }
    }
}

// MARK: - Composition
private extension OnlineResultsView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.xl) {
                winnerCard
                roundBreakdown
                leaderboard
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .actionBar {
            actionSection
                .paddingHorizontalDefault()
                .padding(.bottom, DesignBook.Spacing.sm)
        }
    }

    var winnerCard: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DesignBook.Gradient.celebration)
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.4), radius: 18, x: 0, y: 8)

                Image(systemName: "trophy.fill")
                    .font(DesignBook.IconFont.extraLarge.bold())
                    .foregroundStyle(DesignBook.Color.onGradient)
                    .symbolEffect(.bounce.up.byLayer, options: .nonRepeating, value: !reduceMotion && hasCelebrated)
            }
            .accessibilityHidden(true)
            .decorativeHeroSizing()

            if winners.count == 1, let winner = winners.first {
                VStack(spacing: DesignBook.Spacing.sm) {
                    Text(localized("game.results.winner"))
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .eyebrowUppercase()
                        .tracking(1.6)

                    Text(winner.name)
                        .font(DesignBook.Font.displayMedium)
                        .foregroundStyle(DesignBook.Color.teamText(for: winner.color))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    AnimatedScoreText(
                        value: gameState?.getTotalScore(for: winner.id) ?? 0,
                        font: DesignBook.Font.scaled(56, relativeTo: .largeTitle, weight: .bold),
                        color: DesignBook.Color.teamText(for: winner.color)
                    )

                    Text(localized("game.results.totalPoints"))
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .eyebrowUppercase()
                        .tracking(1.2)
                }
            } else {
                VStack(spacing: DesignBook.Spacing.md) {
                    Text(localized("game.results.winners"))
                        .font(DesignBook.Font.displaySmall)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    ForEach(winners, id: \.id) { winner in
                        VStack(spacing: 4) {
                            Text(winner.name)
                                .font(DesignBook.Font.title1)
                                .foregroundStyle(DesignBook.Color.teamText(for: winner.color))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            AnimatedScoreText(
                                value: gameState?.getTotalScore(for: winner.id) ?? 0,
                                font: DesignBook.Font.displaySmall,
                                color: DesignBook.Color.teamText(for: winner.color)
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignBook.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                .fill(DesignBook.Color.Background.card)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                        .fill(DesignBook.Gradient.celebration.opacity(0.18))
                }
        }
        .shadow(.large)
    }

    var roundBreakdown: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("onlineResults.byRound"))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                ForEach(OnlineGameRound.allCases, id: \.rawValue) { round in
                    HStack {
                        Text(round.title)
                            .font(DesignBook.Font.subheadlineSemibold)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                        Spacer()
                    }
                    .padding(.top, DesignBook.Spacing.xs)

                    ForEach(sortedTeams.sorted { lhs, rhs in
                        (gameState?.getScore(for: lhs.team.id, in: round) ?? 0)
                            > (gameState?.getScore(for: rhs.team.id, in: round) ?? 0)
                    }, id: \.team.id) { item in
                        HStack {
                            Circle()
                                .fill(item.team.color)
                                .frame(width: 8, height: 8)
                            Text(item.team.name)
                                .font(DesignBook.Font.body)
                                .foregroundStyle(DesignBook.Color.Text.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Spacer()
                            Text(verbatim: "\(gameState?.getScore(for: item.team.id, in: round) ?? 0)")
                                .font(DesignBook.Font.bodySemibold)
                                .foregroundStyle(DesignBook.Color.Text.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    var leaderboard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("onlineResults.leaderboard"))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                VStack(spacing: DesignBook.Spacing.sm) {
                    ForEach(Array(sortedTeams.enumerated()), id: \.element.team.id) { index, item in
                        TeamScoreRowView(
                            name: item.team.name,
                            color: item.team.color,
                            rank: index + 1,
                            score: item.score,
                            isWinner: index == 0
                        )
                    }
                }
            }
        }
    }

    var actionSection: some View {
        PrimaryButton(title: localized("onlineResults.returnHome"), icon: "house.fill") {
            leaveRoom()
        }
    }

    func leaveRoom() {
        Task {
            try? await roomManager.leaveRoom()
            navigator.dismiss()
        }
    }
}
