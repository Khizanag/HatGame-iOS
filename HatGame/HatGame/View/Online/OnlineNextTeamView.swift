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
    @State private var forfeits = 0
    @State private var lastAction: GameAction?

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
        currentTeam?.color ?? TeamDefaultColorGenerator.defaultColors[0]
    }

    private var currentRound: OnlineGameRound { gameState?.currentRound ?? .first }
    private var remainingWordCount: Int { gameState?.remainingWordIds.count ?? 0 }

    var body: some View {
        content
            .setDefaultStyle()
            .haptic(.warning, trigger: forfeits)
            .errorAlert($error, title: localized("error.title.connection"), retry: retryLastAction)
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
        .actionBar {
            actionSection
                .paddingHorizontalDefault()
                .padding(.bottom, DesignBook.Spacing.sm)
        }
    }

    var hero: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            ZStack {
                Circle()
                    .fill(tint.opacity(DesignBook.Opacity.tint))
                    .frame(width: DesignBook.Size.heroEmblem, height: DesignBook.Size.heroEmblem)
                Circle()
                    .strokeBorder(tint.opacity(DesignBook.Opacity.disabled), lineWidth: DesignBook.Size.strokeThick)
                    .frame(width: DesignBook.Size.heroEmblem, height: DesignBook.Size.heroEmblem)
                Image(systemName: "target")
                    .font(DesignBook.IconFont.emoji)
                    .foregroundStyle(DesignBook.Color.teamText(for: tint))
            }
            .accessibilityHidden(true)
            .decorativeHeroSizing()

            Text(localized("game.nextTeam.title"))
                .font(DesignBook.Font.caption1Semibold)
                .eyebrowUppercase()
                .tracking(1.6)
                .foregroundStyle(DesignBook.Color.Text.tertiary)

            if let team = currentTeam {
                Text(team.name)
                    .font(DesignBook.Font.displayLarge)
                    .foregroundStyle(DesignBook.Color.teamText(for: tint))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if let totalScore = gameState?.getTotalScore(for: team.id), totalScore != 0 {
                    Text(localized("game.currentScoreLabel \(totalScore)"))
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.teamText(for: tint))
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
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.primary)
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
                                .font(DesignBook.Font.subheadline)
                                .foregroundStyle(DesignBook.Color.Text.tertiary)
                            Text(localized("game.nextTeam.role.guessing"))
                                .font(DesignBook.Font.caption1Semibold)
                                .eyebrowUppercase()
                                .tracking(1.2)
                                .foregroundStyle(DesignBook.Color.Text.tertiary)
                        }

                        VStack(alignment: .leading, spacing: DesignBook.Spacing.xsPlus) {
                            ForEach(guessers, id: \.id) { guesser in
                                HStack(spacing: DesignBook.Spacing.sm) {
                                    Circle()
                                        .fill(DesignBook.Color.Text.primary.opacity(DesignBook.Opacity.medium))
                                        .frame(width: DesignBook.Size.dotSmall, height: DesignBook.Size.dotSmall)
                                    Text(guesser.name)
                                        .font(DesignBook.Font.body)
                                        .foregroundStyle(DesignBook.Color.Text.primary)
                                    if guesser.id == roomManager.currentPlayerId {
                                        RoleBadge(style: .you)
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
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(tint)
                Text(localized(label))
                    .font(DesignBook.Font.caption1Semibold)
                    .eyebrowUppercase()
                    .tracking(1.2)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            HStack(spacing: DesignBook.Spacing.sm) {
                Circle().fill(tint).frame(width: DesignBook.Size.dotMedium, height: DesignBook.Size.dotMedium)
                Text(playerName)
                    .font(DesignBook.Font.bodySemibold)
                    .foregroundStyle(DesignBook.Color.teamText(for: tint))
                if isMe {
                    RoleBadge(style: .you)
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
                    size: DesignBook.Size.largeIconSize,
                    iconSize: 22,
                    color: tint,
                    backgroundColor: tint.opacity(DesignBook.Opacity.light)
                )

                VStack(alignment: .leading, spacing: DesignBook.Spacing.xxs) {
                    Text(currentRound.title)
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    Text(localized("game.wordsRemaining \(remainingWordCount)"))
                        .font(DesignBook.Font.subheadline)
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
        perform(.startTurn)
    }

    /// Host-only: forfeits the turn of an explainer who is offline.
    func skipAwayExplainer() {
        forfeits += 1
        perform(.endTurn)
    }

    func retryLastAction() {
        if let lastAction { perform(lastAction) }
    }

    func perform(_ action: GameAction) {
        guard !isLoading, let room, let playerId = roomManager.currentPlayerId else { return }
        lastAction = action
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
