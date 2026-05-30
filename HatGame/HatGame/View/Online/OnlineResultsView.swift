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
            .navigationTitle(String(localized: "onlineResults.title"))
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
            .sensoryFeedback(.success, trigger: hasCelebrated)
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
        .safeAreaInset(edge: .bottom) {
            actionSection
                .paddingHorizontalDefault()
                .padding(.bottom, DesignBook.Spacing.sm)
                .withFooterGradient()
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
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce.up.byLayer, options: .nonRepeating, value: hasCelebrated)
            }
            .accessibilityHidden(true)

            if winners.count == 1, let winner = winners.first {
                VStack(spacing: DesignBook.Spacing.sm) {
                    Text("game.results.winner")
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .textCase(.uppercase)
                        .tracking(1.6)

                    Text(winner.name)
                        .font(DesignBook.Font.title)
                        .foregroundStyle(Color(hex: winner.colorHex) ?? DesignBook.Color.Text.primary)
                        .multilineTextAlignment(.center)

                    AnimatedScoreText(
                        value: gameState?.getTotalScore(for: winner.id) ?? 0,
                        font: .system(size: 56, weight: .bold, design: .rounded),
                        color: Color(hex: winner.colorHex) ?? DesignBook.Color.Text.primary
                    )

                    Text("game.results.totalPoints")
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
            } else {
                VStack(spacing: DesignBook.Spacing.md) {
                    Text("game.results.winners")
                        .font(DesignBook.Font.title2)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    ForEach(winners, id: \.id) { winner in
                        VStack(spacing: 4) {
                            Text(winner.name)
                                .font(DesignBook.Font.title3)
                                .foregroundStyle(Color(hex: winner.colorHex) ?? DesignBook.Color.Text.primary)
                            AnimatedScoreText(
                                value: gameState?.getTotalScore(for: winner.id) ?? 0,
                                font: DesignBook.Font.title2,
                                color: Color(hex: winner.colorHex) ?? DesignBook.Color.Text.primary
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
                Text("onlineResults.byRound")
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                ForEach(OnlineGameRound.allCases, id: \.rawValue) { round in
                    HStack {
                        Text(round.title)
                            .font(DesignBook.Font.captionBold)
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
                                .fill(Color(hex: item.team.colorHex) ?? DesignBook.Color.Text.accent)
                                .frame(width: 8, height: 8)
                            Text(item.team.name)
                                .font(DesignBook.Font.body)
                                .foregroundStyle(DesignBook.Color.Text.primary)
                            Spacer()
                            Text(verbatim: "\(gameState?.getScore(for: item.team.id, in: round) ?? 0)")
                                .font(DesignBook.Font.bodyBold)
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
                Text("onlineResults.leaderboard")
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                VStack(spacing: DesignBook.Spacing.sm) {
                    ForEach(Array(sortedTeams.enumerated()), id: \.element.team.id) { index, item in
                        TeamScoreRowView(
                            name: item.team.name,
                            color: Color(hex: item.team.colorHex) ?? DesignBook.Color.Text.accent,
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
        PrimaryButton(title: String(localized: "onlineResults.returnHome"), icon: "house.fill") {
            leaveRoom()
        }
    }

    func leaveRoom() {
        DesignBook.Haptics.tap()
        Task {
            try? await roomManager.leaveRoom()
            navigator.dismiss()
        }
    }
}

// MARK: - Localized round titles
private extension OnlineGameRound {
    var title: String {
        switch self {
        case .first: String(localized: "round.first.title")
        case .second: String(localized: "round.second.title")
        case .third: String(localized: "round.third.title")
        }
    }
}
