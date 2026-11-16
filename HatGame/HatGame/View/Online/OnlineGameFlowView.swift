//
//  OnlineGameFlowView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

/// Single-screen controller pushed onto the OnlineFlow navigation stack once
/// a player has joined or created a room. Routes between the lobby, the
/// word-submission screens, and the game-phase views based on room status
/// and the live `OnlineGameState.phase`. Re-uses the GameSyncManager
/// already in the environment from `OnlineFlowView`.
struct OnlineGameFlowView: View {
    @Environment(RoomManager.self) private var roomManager
    @Environment(GameSyncManager.self) private var gameSyncManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The host chose to start with the words already submitted.
    @State private var startsWithSubmittedWords: Bool = false

    private var room: GameRoom? { roomManager.room }
    private var roomStatus: RoomStatus? { room?.status }
    private var gamePhase: GamePhase? { room?.gameState?.phase }
    private var isAutomaticWords: Bool { room?.settings.isAutomaticWords == true }

    private var allPlayersSubmittedWords: Bool {
        room.map(RoomRules.allWordsSubmitted) ?? false
    }

    /// The host-side setup this device still owes the room, if any.
    private var setupStep: GameSetupStep? {
        guard let room, let playerId = roomManager.currentPlayerId else { return nil }
        return RoomRules.pendingSetupStep(in: room, for: playerId, startsWithSubmittedWords: startsWithSubmittedWords)
    }

    /// Offered to whoever can act as host while someone is still typing.
    private var startWithSubmittedWords: (() -> Void)? {
        guard roomManager.canActAsHost, room.map(RoomRules.canStartWithSubmittedWords) == true else { return nil }
        return { startsWithSubmittedWords = true }
    }

    var body: some View {
        content
            .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: roomStatus)
            .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: gamePhase)
            .task(id: setupStep) {
                await OnlineGameSetup.run(setupStep, roomManager: roomManager, gameSyncManager: gameSyncManager)
            }
    }
}

// MARK: - Composition
private extension OnlineGameFlowView {
    @ViewBuilder
    var content: some View {
        switch roomManager.connectionState {
        case .closed:
            closedState.transition(.opacity)
        case .unsupported:
            unsupportedState.transition(.opacity)
        case .idle, .joining, .live:
            roomContent
        }
    }

    @ViewBuilder
    var roomContent: some View {
        if room?.isSupported == false {
            unsupportedState.transition(.opacity)
        } else {
            switch roomStatus {
            case .waiting, .setup:
                RoomLobbyView().transition(.opacity)
            case .playing:
                playingContent.transition(.opacity)
            case .finished:
                OnlineResultsView().transition(.opacity)
            case .unsupported:
                unsupportedState.transition(.opacity)
            case nil:
                joiningState.transition(.opacity)
            }
        }
    }

    /// The host closed the room while this device was in it.
    var closedState: some View {
        OnlineNoticeView(
            symbol: "door.left.hand.closed",
            title: localized("online.session.closed"),
            message: localized("online.session.closed.message"),
            actionTitle: localized("local.session.hostLost.action"),
            action: leaveToMenu
        )
    }

    /// A newer build wrote a status, phase, or round this one can't read.
    var unsupportedState: some View {
        OnlineNoticeView(
            symbol: "arrow.down.app",
            title: localized("online.unsupported.title"),
            message: localized("online.unsupported.message"),
            actionTitle: localized("local.session.hostLost.action"),
            action: leaveToMenu
        )
    }

    /// First-load state before the Firebase room observer delivers a
    /// snapshot. Mirrors LocalSessionView.connectingState so the two
    /// modes feel deliberately the same, not accidentally re-used.
    var joiningState: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(DesignBook.Gradient.primary)
                    .frame(width: 120, height: 120)
                    .blur(radius: 28)
                    .opacity(0.55)
                Circle()
                    .fill(DesignBook.Color.Background.card)
                    .frame(width: 96, height: 96)
                    .shadow(.medium)
                Image(systemName: "wifi")
                    .font(DesignBook.IconFont.sized(42, relativeTo: .largeTitle, weight: .bold))
                    .decorativeHeroSizing()
                    .foregroundStyle(DesignBook.Gradient.primary)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
            }
            .accessibilityHidden(true)
            Text(localized("online.session.joining"))
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
            Text(localized("online.session.joiningHint"))
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignBook.Spacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .setDefaultBackground()
    }

    /// A game state, once written, wins over everything else: a player who
    /// rejoins mid-game, or never submitted before the host started, goes
    /// straight to the game rather than to word entry.
    @ViewBuilder
    var playingContent: some View {
        if room?.gameState != nil {
            gamePhaseContent
        } else if isAutomaticWords || allPlayersSubmittedWords || startsWithSubmittedWords {
            OnlineWaitingView(message: localized("online.preparingGame"))
        } else if roomManager.currentPlayer?.hasSubmittedWords == true {
            OnlineWaitingView(
                message: localized("online.waitingForOthers"),
                onStartWithSubmittedWords: startWithSubmittedWords
            )
        } else {
            OnlineWordInputView()
        }
    }

    @ViewBuilder
    var gamePhaseContent: some View {
        switch gamePhase {
        case .teamPrep: OnlineNextTeamView()
        case .playing: OnlinePlayView()
        case .turnResults: OnlineTurnResultsView()
        case .roundResults: OnlineRoundResultsView()
        case .finished: OnlineResultsView()
        case .unsupported: unsupportedState
        case nil: OnlineWaitingView(message: localized("online.preparingGame"))
        }
    }

    /// Detaches without writing — the room is gone or unreadable — and
    /// returns to the online menu.
    func leaveToMenu() {
        Task {
            try? await roomManager.leaveRoom()
            navigator.popToRoot()
        }
    }
}
