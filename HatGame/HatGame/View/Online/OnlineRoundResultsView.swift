//
//  OnlineRoundResultsView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct OnlineRoundResultsView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(RoomManager.self) private var roomManager
    @Environment(GameSyncManager.self) private var gameSyncManager

    @State private var isLoading: Bool = false
    @State private var hasCelebrated: Bool = false
    @State private var error: Error?

    private var room: GameRoom? { roomManager.room }
    private var gameState: OnlineGameState? { room?.gameState }
    private var teams: [OnlineTeam] { room?.teams ?? [] }

    private var currentRound: OnlineGameRound { gameState?.currentRound ?? .first }
    /// On the round-results screen `currentRound` is the round that just ended.
    private var nextRound: OnlineGameRound? { currentRound.next }

    private var roundLeader: OnlineTeam? {
        teams.max { lhs, rhs in
            (gameState?.getScore(for: lhs.id, in: currentRound) ?? 0)
                < (gameState?.getScore(for: rhs.id, in: currentRound) ?? 0)
        }
    }

    var body: some View {
        content
            .setDefaultStyle()
            .overlay {
                if hasCelebrated {
                    ConfettiView(isActive: true).ignoresSafeArea().allowsHitTesting(false)
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                hasCelebrated = true
            }
            .errorAlert($error, title: localized("error.title.continue"))
    }
}

// MARK: - Composition
private extension OnlineRoundResultsView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                header
                roundScoresCard
                totalScoresCard
                if let nextRound { nextRoundCard(nextRound) }
            }
            .paddingHorizontalDefault()
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .actionBar {
            actionSection
                .paddingHorizontalDefault()
                .padding(.bottom, DesignBook.Spacing.sm)
        }
    }

    var header: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            Text(verbatim: "🏁")
                .font(DesignBook.IconFont.emoji)
                .decorativeHeroSizing()
                .accessibilityHidden(true)
            Text(localized("onlineRoundResults.roundComplete"))
                .font(DesignBook.Font.displayLarge)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            Text(currentRound.title)
                .font(DesignBook.Font.title1)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
        .padding(.top, DesignBook.Spacing.lg)
    }

    var roundScoresCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("onlineRoundResults.roundScores"))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                let ranked = teams.enumerated()
                    .sorted { lhs, rhs in
                        (gameState?.getScore(for: lhs.element.id, in: currentRound) ?? 0)
                            > (gameState?.getScore(for: rhs.element.id, in: currentRound) ?? 0)
                    }

                ForEach(Array(ranked.enumerated()), id: \.element.element.id) { rank, item in
                    let team = item.element
                    let isLeader = team.id == roundLeader?.id
                    HStack(spacing: DesignBook.Spacing.md) {
                        medalIcon(for: rank).frame(width: 30)
                        Circle()
                            .fill(team.color)
                            .frame(width: 10, height: 10)
                        Text(team.name)
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer()
                        AnimatedScoreText(
                            value: gameState?.getScore(for: team.id, in: currentRound) ?? 0,
                            font: DesignBook.Font.title1,
                            color: isLeader
                                ? DesignBook.Color.teamText(for: team.color)
                                : DesignBook.Color.Text.secondary,
                            duration: 0.6
                        )
                    }
                    .padding(.vertical, DesignBook.Spacing.xs)
                }
            }
        }
    }

    var totalScoresCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("onlineRoundResults.totalScores"))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                let ranked = teams.sorted { lhs, rhs in
                    (gameState?.getTotalScore(for: lhs.id) ?? 0)
                        > (gameState?.getTotalScore(for: rhs.id) ?? 0)
                }

                ForEach(Array(ranked.enumerated()), id: \.element.id) { rank, team in
                    HStack(spacing: DesignBook.Spacing.md) {
                        Text(verbatim: "\(rank + 1)")
                            .font(DesignBook.Font.subheadlineSemibold)
                            .foregroundStyle(rank == 0
                                ? DesignBook.Color.onAccent(for: team.color)
                                : DesignBook.Color.Text.primary)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle().fill(rank == 0
                                    ? team.color
                                    : DesignBook.Color.Text.tertiary.opacity(0.4))
                            }
                            .monospacedDigit()

                        Circle()
                            .fill(team.color)
                            .frame(width: 10, height: 10)

                        Text(team.name)
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        Spacer()

                        AnimatedScoreText(
                            value: gameState?.getTotalScore(for: team.id) ?? 0,
                            font: DesignBook.Font.title1,
                            color: rank == 0
                                ? DesignBook.Color.teamText(for: team.color)
                                : DesignBook.Color.Text.secondary,
                            duration: 0.7
                        )
                    }
                    .padding(.vertical, DesignBook.Spacing.xs)
                }
            }
        }
    }

    func nextRoundCard(_ round: OnlineGameRound) -> some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.sm) {
                Text(localized("onlineRoundResults.nextRound"))
                    .font(DesignBook.Font.caption1Semibold)
                    .eyebrowUppercase()
                    .tracking(1.6)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)

                Text(round.title)
                    .font(DesignBook.Font.displaySmall)
                    .foregroundStyle(DesignBook.Color.Text.accent)

                Text(round.description)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, DesignBook.Spacing.sm)
        }
    }

    @ViewBuilder
    func medalIcon(for index: Int) -> some View {
        switch index {
        case 0: Text(verbatim: "🥇").font(DesignBook.Font.title1)
        case 1: Text(verbatim: "🥈").font(DesignBook.Font.title1)
        case 2: Text(verbatim: "🥉").font(DesignBook.Font.title1)
        default:
            Text(verbatim: "\(index + 1)")
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
        }
    }

    @ViewBuilder
    var actionSection: some View {
        if roomManager.canActAsHost {
            PrimaryButton(
                title: nextRound == nil
                    ? localized("onlineRoundResults.finish")
                    : localized("onlineRoundResults.startNextRound"),
                icon: "play.fill"
            ) {
                advance()
            }
            .disabled(isLoading)
        } else {
            VStack(spacing: DesignBook.Spacing.sm) {
                Text(localized("onlineRoundResults.waitingForHost"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                ProgressView()
            }
        }
    }
}

// MARK: - Actions
private extension OnlineRoundResultsView {
    func advance() {
        guard !isLoading, let room, let playerId = roomManager.currentPlayerId else { return }
        isLoading = true
        Task {
            do {
                try await gameSyncManager.perform(.advanceAfterRoundResults, room: room, playerId: playerId)
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
}
