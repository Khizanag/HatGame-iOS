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

    @State private var isLoading: Bool = false
    @State private var hasCelebrated: Bool = false
    @State private var error: Error?

    private var room: GameRoom? { roomManager.room }
    private var gameState: OnlineGameState? { room?.gameState }
    private var teams: [OnlineTeam] { room?.teams ?? [] }
    private var players: [OnlinePlayer] { room?.players ?? [] }

    private var currentTeam: OnlineTeam? {
        guard let state = gameState else { return nil }
        return teams[safe: state.currentTeamIndex]
    }

    private var currentRound: OnlineGameRound { gameState?.currentRound ?? .first }

    private var roundScore: Int {
        guard let teamId = currentTeam?.id else { return 0 }
        return gameState?.getScore(for: teamId, in: currentRound) ?? 0
    }

    private var isActivePlayer: Bool {
        gameState?.activePlayerId == roomManager.currentPlayerId
    }

    private var tint: Color {
        currentTeam.flatMap { Color(hex: $0.colorHex) } ?? DesignBook.Color.Text.accent
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    DesignBook.Haptics.success()
                    hasCelebrated = true
                }
            }
            .alert(localized("common.error"), isPresented: errorBinding) {
                Button(localized("common.gotIt")) { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
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
        .safeAreaInset(edge: .bottom) {
            actionSection
                .paddingHorizontalDefault()
                .padding(.bottom, DesignBook.Spacing.sm)
                .withFooterGradient()
        }
    }

    var header: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            ZStack {
                Circle().fill(DesignBook.Color.Status.success.opacity(0.18)).frame(width: 88, height: 88)
                Image(systemName: "sparkles")
                    // Hero celebration glyph; unique size with no Dynamic Type token.
                    // swiftlint:disable:next no_inline_font
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(DesignBook.Color.Status.success)
                    .symbolEffect(.bounce, options: .nonRepeating, value: hasCelebrated)
            }
            Text(localized("onlineTurnResults.title"))
                .font(DesignBook.Font.largeTitle)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
        }
    }

    var teamResultCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.sm) {
                if let team = currentTeam {
                    Text(team.name)
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(tint)
                }
                HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.sm) {
                    AnimatedScoreText(
                        value: roundScore,
                        font: .system(size: 64, weight: .bold, design: .rounded),
                        color: tint,
                        duration: 0.7
                    )
                    Text(roundScore == 1 ? "onlineTurnResults.wordUnit.one" : "onlineTurnResults.wordUnit.many")
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                }
            }
        }
    }

    var scoreboardCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("onlineTurnResults.standings"))
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                ForEach(Array(sortedTeams.enumerated()), id: \.element.id) { index, team in
                    HStack(spacing: DesignBook.Spacing.md) {
                        Text(verbatim: "\(index + 1)")
                            .font(DesignBook.Font.captionBold)
                            // White rank numeral sits on a colored team badge.
                            // swiftlint:disable:next no_raw_foreground_white_black
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle().fill(index == 0
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
                            color: index == 0
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

    @ViewBuilder
    var actionSection: some View {
        if isActivePlayer {
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
    var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

    func continueFlow() {
        guard let roomId = room?.id, let state = gameState else { return }
        isLoading = true
        DesignBook.Haptics.tap()
        Task {
            do {
                try await gameSyncManager.advanceAfterTurnResults(
                    roomId: roomId,
                    gameState: state,
                    teams: teams,
                    players: players
                )
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
}

// MARK: - Safe subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
