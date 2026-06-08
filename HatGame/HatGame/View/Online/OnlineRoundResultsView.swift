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

    private var room: GameRoom? { roomManager.room }
    private var gameState: OnlineGameState? { room?.gameState }
    private var teams: [OnlineTeam] { room?.teams ?? [] }
    private var players: [OnlinePlayer] { room?.players ?? [] }

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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    DesignBook.Haptics.success()
                    hasCelebrated = true
                }
            }
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
        .safeAreaInset(edge: .bottom) {
            actionSection
                .paddingHorizontalDefault()
                .padding(.bottom, DesignBook.Spacing.sm)
                .withFooterGradient()
        }
    }

    var header: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            Text("🏁").font(DesignBook.IconFont.emoji)
            Text(localized("onlineRoundResults.roundComplete"))
                .font(DesignBook.Font.largeTitle)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
            Text(currentRound.title)
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
        .padding(.top, DesignBook.Spacing.lg)
    }

    var roundScoresCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("onlineRoundResults.roundScores"))
                    .font(DesignBook.Font.headline)
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
                            .fill(Color(hex: team.colorHex) ?? DesignBook.Color.Text.accent)
                            .frame(width: 10, height: 10)
                        Text(team.name)
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                        Spacer()
                        AnimatedScoreText(
                            value: gameState?.getScore(for: team.id, in: currentRound) ?? 0,
                            font: DesignBook.Font.title3,
                            color: isLeader
                                ? (Color(hex: team.colorHex) ?? DesignBook.Color.Text.accent)
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
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                let ranked = teams.sorted { lhs, rhs in
                    (gameState?.getTotalScore(for: lhs.id) ?? 0)
                        > (gameState?.getTotalScore(for: rhs.id) ?? 0)
                }

                ForEach(Array(ranked.enumerated()), id: \.element.id) { rank, team in
                    HStack(spacing: DesignBook.Spacing.md) {
                        Text(verbatim: "\(rank + 1)")
                            .font(DesignBook.Font.captionBold)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle().fill(rank == 0
                                    ? (Color(hex: team.colorHex) ?? DesignBook.Color.Text.accent)
                                    : DesignBook.Color.Text.tertiary.opacity(0.4))
                            }
                            .monospacedDigit()

                        Circle()
                            .fill(Color(hex: team.colorHex) ?? DesignBook.Color.Text.accent)
                            .frame(width: 10, height: 10)

                        Text(team.name)
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.primary)

                        Spacer()

                        AnimatedScoreText(
                            value: gameState?.getTotalScore(for: team.id) ?? 0,
                            font: DesignBook.Font.title3,
                            color: rank == 0
                                ? (Color(hex: team.colorHex) ?? DesignBook.Color.Text.accent)
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
                    .font(DesignBook.Font.smallCaption)
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)

                Text(round.title)
                    .font(DesignBook.Font.title2)
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
        case 0: Text("🥇").font(DesignBook.Font.title3)
        case 1: Text("🥈").font(DesignBook.Font.title3)
        case 2: Text("🥉").font(DesignBook.Font.title3)
        default:
            Text(verbatim: "\(index + 1)")
                .font(DesignBook.Font.headline)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
        }
    }

    @ViewBuilder
    var actionSection: some View {
        if roomManager.isHost {
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
        guard let roomId = room?.id, let state = gameState else { return }
        isLoading = true
        DesignBook.Haptics.confirm()
        Task {
            try? await gameSyncManager.advanceAfterRoundResults(
                roomId: roomId,
                gameState: state,
                teams: teams,
                players: players
            )
            isLoading = false
        }
    }
}

// MARK: - Localized round titles
private extension OnlineGameRound {
    var title: String {
        switch self {
        case .first: localized("round.first.title")
        case .second: localized("round.second.title")
        case .third: localized("round.third.title")
        }
    }

    var description: String {
        switch self {
        case .first: localized("round.first.description")
        case .second: localized("round.second.description")
        case .third: localized("round.third.description")
        }
    }
}
