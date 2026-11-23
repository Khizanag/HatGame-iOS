//
//  OnlineTurnResultsView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct OnlineTurnResultsView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(RoomManager.self) private var roomManager
    @Environment(GameSyncManager.self) private var gameSyncManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isLoading: Bool = false
    @State private var hasCelebrated: Bool = false
    @State private var error: Error?

    private var room: GameRoom? { roomManager.room }
    private var gameState: OnlineGameState? { room?.gameState }
    private var teams: [OnlineTeam] { room?.teams ?? [] }

    private var currentTeam: OnlineTeam? {
        gameState.flatMap { OnlineGameRules.currentTeam($0, teams: teams) }
    }

    private var currentRound: OnlineGameRound { gameState?.currentRound ?? .first }

    private var roundScore: Int {
        guard let teamId = currentTeam?.id else { return 0 }
        return gameState?.getScore(for: teamId, in: currentRound) ?? 0
    }

    private var isActivePlayer: Bool {
        gameState?.activePlayerId == roomManager.currentPlayerId
    }

    /// The host may move the game past an explainer who has gone offline,
    /// so one backgrounded device cannot wedge the room.
    private var canCoverForAwayExplainer: Bool {
        guard roomManager.canActAsHost, !isActivePlayer, let state = gameState else { return false }
        return OnlineGameRules.isActivePlayerAway(state, players: room?.players ?? [])
    }

    private var tint: Color {
        currentTeam?.color ?? TeamDefaultColorGenerator.defaultColors[0]
    }

    private var sortedTeams: [OnlineTeam] {
        teams.sorted { lhs, rhs in
            (gameState?.getTotalScore(for: lhs.id) ?? 0) > (gameState?.getTotalScore(for: rhs.id) ?? 0)
        }
    }

    var body: some View {
        content
            .setDefaultStyle()
            .overlay {
                if hasCelebrated, roundScore >= 5 {
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
private extension OnlineTurnResultsView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                Spacer().frame(height: DesignBook.Spacing.lg)
                header
                teamResultCard
                scoreboardCard
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
            ZStack {
                Circle().fill(DesignBook.Color.Status.success.opacity(0.18)).frame(width: 88, height: 88)
                Image(systemName: "sparkles")
                    .font(DesignBook.IconFont.sized(38, relativeTo: .largeTitle, weight: .bold))
                    .decorativeHeroSizing()
                    .foregroundStyle(DesignBook.Color.Status.success)
                    .symbolEffect(.bounce, options: .nonRepeating, value: !reduceMotion && hasCelebrated)
            }
            Text(localized("onlineTurnResults.title"))
                .font(DesignBook.Font.displayLarge)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
        }
    }

    var teamResultCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.sm) {
                if let team = currentTeam {
                    Text(team.name)
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.teamText(for: tint))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.sm) {
                    AnimatedScoreText(
                        value: roundScore,
                        font: DesignBook.Font.heroScore,
                        color: DesignBook.Color.teamText(for: tint),
                        duration: 0.7
                    )
                    Text(localized("game.turnResults.wordsUnit \(roundScore)"))
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                }
            }
        }
    }

    var scoreboardCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("onlineTurnResults.standings"))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                ForEach(Array(sortedTeams.enumerated()), id: \.element.id) { index, team in
                    HStack(spacing: DesignBook.Spacing.md) {
                        Text(verbatim: "\(index + 1)")
                            .font(DesignBook.Font.subheadlineSemibold)
                            .foregroundStyle(index == 0
                                ? DesignBook.Color.onAccent(for: team.color)
                                : DesignBook.Color.Text.primary)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle().fill(index == 0
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
                            color: index == 0
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

    @ViewBuilder
    var actionSection: some View {
        if isActivePlayer || canCoverForAwayExplainer {
            PrimaryButton(title: localized("common.buttons.continue"), icon: "arrow.right.circle.fill") {
                continueFlow()
            }
            .disabled(isLoading)
        } else {
            VStack(spacing: DesignBook.Spacing.sm) {
                Text(localized("onlineTurnResults.waitingForNext"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                ProgressView()
            }
        }
    }
}

// MARK: - Actions
private extension OnlineTurnResultsView {
    func continueFlow() {
        guard !isLoading, let room, let playerId = roomManager.currentPlayerId else { return }
        isLoading = true
        Task {
            do {
                try await gameSyncManager.perform(.advanceAfterTurnResults, room: room, playerId: playerId)
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
}
