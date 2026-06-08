//
//  OnlineNextTeamView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct OnlineNextTeamView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(RoomManager.self) private var roomManager
    @Environment(GameSyncManager.self) private var gameSyncManager

    @State private var isLoading: Bool = false

    private var room: GameRoom? { roomManager.room }
    private var gameState: OnlineGameState? { room?.gameState }
    private var teams: [OnlineTeam] { room?.teams ?? [] }
    private var players: [OnlinePlayer] { room?.players ?? [] }

    private var currentTeam: OnlineTeam? {
        guard let state = gameState else { return nil }
        return teams[safe: state.currentTeamIndex]
    }

    private var teamPlayers: [OnlinePlayer] {
        guard let team = currentTeam else { return [] }
        if !team.playerIds.isEmpty {
            let lookup = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            return team.playerIds.compactMap { lookup[$0] }
        }
        return players.filter { $0.teamId == team.id }
    }

    private var explainer: OnlinePlayer? {
        guard let team = currentTeam, let state = gameState else { return nil }
        let index = state.explainerIndex(for: team.id)
        return teamPlayers[safe: index]
    }

    private var guessers: [OnlinePlayer] {
        guard let explainerId = explainer?.id else { return [] }
        return teamPlayers.filter { $0.id != explainerId }
    }

    private var isActivePlayer: Bool {
        gameState?.activePlayerId == roomManager.currentPlayerId
    }

    private var isMyTeamsTurn: Bool {
        guard let teamId = currentTeam?.id else { return false }
        return roomManager.currentPlayer?.teamId == teamId
    }

    private var tint: Color {
        currentTeam.flatMap { Color(hex: $0.colorHex) } ?? DesignBook.Color.Text.accent
    }

    private var currentRound: OnlineGameRound { gameState?.currentRound ?? .first }
    private var remainingWordCount: Int { gameState?.remainingWordIds.count ?? 0 }

    var body: some View {
        content
            .setDefaultStyle()
    }
}

// MARK: - Composition
private extension OnlineNextTeamView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                hero
                rolesCard
                statusCard
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

    var hero: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 120, height: 120)
                Circle().strokeBorder(tint.opacity(0.4), lineWidth: 2).frame(width: 120, height: 120)
                Text("🎯").font(.system(size: 72))
            }
            .accessibilityHidden(true)

            Text(localized("game.nextTeam.title"))
                .font(DesignBook.Font.smallCaption)
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(DesignBook.Color.Text.tertiary)

            if let team = currentTeam {
                Text(team.name)
                    .font(DesignBook.Font.largeTitle)
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.center)

                if let totalScore = gameState?.getTotalScore(for: team.id), totalScore > 0 {
                    Text(String(format: localized("game.currentScoreLabel"), totalScore))
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(tint)
                }
            }
        }
        .padding(.top, DesignBook.Spacing.md)
    }

    var rolesCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack {
                    Text(localized("onlineNextTeam.teamRoles"))
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                }

                if let explainer {
                    rolePill(
                        icon: "person.wave.2.fill",
                        label: "game.nextTeam.role.explaining",
                        playerName: explainer.name,
                        isMe: explainer.id == roomManager.currentPlayerId,
                        emphasized: true
                    )
                }

                if !guessers.isEmpty {
                    VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
                        HStack(spacing: DesignBook.Spacing.xs) {
                            Image(systemName: "lightbulb.fill")
                                .font(DesignBook.Font.caption)
                                .foregroundStyle(DesignBook.Color.Text.accent)
                            Text(localized("game.nextTeam.role.guessing"))
                                .font(DesignBook.Font.smallCaption)
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .foregroundStyle(DesignBook.Color.Text.tertiary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(guessers, id: \.id) { guesser in
                                HStack(spacing: DesignBook.Spacing.sm) {
                                    Circle()
                                        .fill(DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.medium))
                                        .frame(width: DesignBook.Size.dotSmall, height: DesignBook.Size.dotSmall)
                                    Text(guesser.name)
                                        .font(DesignBook.Font.body)
                                        .foregroundStyle(DesignBook.Color.Text.primary)
                                    if guesser.id == roomManager.currentPlayerId {
                                        Text(localized("onlineNextTeam.you"))
                                            .font(DesignBook.Font.captionBold)
                                            .foregroundStyle(DesignBook.Color.Text.accent)
                                    }
                                }
                            }
                        }
                        .padding(DesignBook.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignBook.Color.Background.secondary)
                        .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                    }
                }
            }
        }
    }

    func rolePill(
        icon: String,
        label: LocalizedStringKey,
        playerName: String,
        isMe: Bool,
        emphasized: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            HStack(spacing: DesignBook.Spacing.xs) {
                Image(systemName: icon)
                    .font(DesignBook.Font.caption)
                    .foregroundStyle(tint)
                Text(label)
                    .font(DesignBook.Font.smallCaption)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            HStack(spacing: DesignBook.Spacing.sm) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(playerName)
                    .font(DesignBook.Font.bodyBold)
                    .foregroundStyle(tint)
                if isMe {
                    Text(localized("onlineNextTeam.you"))
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignBook.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(tint))
                }
            }
            .padding(DesignBook.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(emphasized ? 0.12 : 0.08))
            .cornerRadius(DesignBook.Size.smallCardCornerRadius)
        }
    }

    var statusCard: some View {
        GameCard {
            HStack(spacing: DesignBook.Spacing.md) {
                CircularIconContainer(
                    icon: "flag.fill",
                    size: 48,
                    iconSize: 22,
                    color: tint,
                    backgroundColor: tint.opacity(0.12)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentRound.title)
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    Text(String(format: localized("game.wordsRemainingLabel"), remainingWordCount))
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    var actionSection: some View {
        if isActivePlayer {
            PrimaryButton(title: localized("common.buttons.play"), icon: "play.fill") {
                startTurn()
            }
            .disabled(isLoading)
        } else if isMyTeamsTurn {
            VStack(spacing: DesignBook.Spacing.sm) {
                Text(String(format: localized("onlineNextTeam.waitingForName"), explainer?.name ?? ""))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                ProgressView()
            }
        } else {
            VStack(spacing: DesignBook.Spacing.sm) {
                Text(String(format: localized("onlineNextTeam.spectating"), currentTeam?.name ?? ""))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                ProgressView()
            }
        }
    }
}

// MARK: - Actions
private extension OnlineNextTeamView {
    func startTurn() {
        guard let roomId = room?.id, let state = gameState else { return }
        isLoading = true
        DesignBook.Haptics.confirm()
        Task {
            try? await gameSyncManager.startTurn(roomId: roomId, gameState: state)
            isLoading = false
        }
    }
}

// MARK: - Round title helper
private extension OnlineGameRound {
    var title: String {
        switch self {
        case .first: localized("round.first.title")
        case .second: localized("round.second.title")
        case .third: localized("round.third.title")
        }
    }
}

// MARK: - Safe subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
