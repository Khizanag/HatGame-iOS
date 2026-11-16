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
    @State private var error: Error?

    private var room: GameRoom? { roomManager.room }
    private var gameState: OnlineGameState? { room?.gameState }
    private var teams: [OnlineTeam] { room?.teams ?? [] }
    private var players: [OnlinePlayer] { room?.players ?? [] }

    private var currentTeam: OnlineTeam? {
        gameState.flatMap { OnlineGameRules.currentTeam($0, teams: teams) }
    }

    private var teamPlayers: [OnlinePlayer] {
        guard let team = currentTeam else { return [] }
        return OnlineGameRules.playersInTeam(team, allPlayers: players)
    }

    /// The player the synced state names as explainer — the same id that
    /// gates the Play button, so the roles card can never disagree with it.
    private var explainer: OnlinePlayer? {
        guard let activeId = gameState?.activePlayerId else { return nil }
        return players.first { $0.id == activeId }
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

    /// The host may move the game past an explainer who has gone offline,
    /// so one backgrounded device cannot wedge the room.
    private var canCoverForAwayExplainer: Bool {
        guard roomManager.canActAsHost, !isActivePlayer, let state = gameState else { return false }
        return OnlineGameRules.isActivePlayerAway(state, players: room?.players ?? [])
    }

    private var tint: Color {
        currentTeam?.color ?? DesignBook.Color.Text.accent
    }

    private var currentRound: OnlineGameRound { gameState?.currentRound ?? .first }
    private var remainingWordCount: Int { gameState?.remainingWordIds.count ?? 0 }

    var body: some View {
        content
            .setDefaultStyle()
            .errorAlert($error)
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
                Text(verbatim: "🎯").font(DesignBook.IconFont.emoji)
            }
            .accessibilityHidden(true)
            .decorativeHeroSizing()

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
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if let totalScore = gameState?.getTotalScore(for: team.id), totalScore > 0 {
                    Text(localized("game.currentScoreLabel \(totalScore)"))
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
                        .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
                    }
                }
            }
        }
    }

    func rolePill(
        icon: String,
        label: String.LocalizationValue,
        playerName: String,
        isMe: Bool,
        emphasized: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            HStack(spacing: DesignBook.Spacing.xs) {
                Image(systemName: icon)
                    .font(DesignBook.Font.caption)
                    .foregroundStyle(tint)
                Text(localized(label))
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
                        .foregroundStyle(DesignBook.Color.onAccent(for: tint))
                        .padding(.horizontal, DesignBook.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(tint))
                }
            }
            .padding(DesignBook.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(emphasized ? 0.12 : 0.08))
            .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
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
                    Text(localized("game.wordsRemaining \(remainingWordCount)"))
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
        } else {
            VStack(spacing: DesignBook.Spacing.sm) {
                Text(waitingMessage)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                if canCoverForAwayExplainer {
                    SecondaryButton(title: localized("game.skip"), icon: "forward.end.fill") {
                        skipAwayExplainer()
                    }
                    .disabled(isLoading)
                } else {
                    ProgressView()
                }
            }
        }
    }

    var waitingMessage: String {
        isMyTeamsTurn
            ? String(format: localized("onlineNextTeam.waitingForName"), explainer?.name ?? "")
            : String(format: localized("onlineNextTeam.spectating"), currentTeam?.name ?? "")
    }
}

// MARK: - Actions
private extension OnlineNextTeamView {
    func startTurn() {
        DesignBook.Haptics.confirm()
        perform(.startTurn)
    }

    /// Host-only: forfeits the turn of an explainer who is offline.
    func skipAwayExplainer() {
        DesignBook.Haptics.rigid()
        perform(.endTurn)
    }

    func perform(_ action: GameAction) {
        guard !isLoading, let room, let playerId = roomManager.currentPlayerId else { return }
        isLoading = true
        Task {
            do {
                try await gameSyncManager.perform(action, room: room, playerId: playerId)
            } catch {
                self.error = error
            }
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
        case .third, .unsupported: localized("round.third.title")
        }
    }
}
