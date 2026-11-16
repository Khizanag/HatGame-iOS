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

    @State private var hasInitializedGame: Bool = false
    @State private var hasGeneratedWords: Bool = false

    private var room: GameRoom? { roomManager.room }
    private var roomStatus: RoomStatus? { room?.status }
    private var gamePhase: GamePhase? { room?.gameState?.phase }
    private var isAutomaticWords: Bool { room?.settings.isAutomaticWords == true }

    private var allPlayersSubmittedWords: Bool {
        room.map(RoomRules.allWordsSubmitted) ?? false
    }

    var body: some View {
        content
            .animation(DesignBook.Motion.smooth, value: roomStatus)
            .animation(DesignBook.Motion.smooth, value: gamePhase)
            .onChange(of: allPlayersSubmittedWords) { _, allSubmitted in
                guard allSubmitted, roomManager.isHost else { return }
                initializeGameIfNeeded()
            }
            .onChange(of: roomStatus) { _, status in
                guard status == .playing else { return }
                generateWordsIfNeeded()
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
            title: localized("local.session.hostLost"),
            message: localized("local.session.hostLost.message"),
            actionTitle: localized("local.session.hostLost.action"),
            action: leaveToMenu
        )
    }

    /// A newer build wrote a status, phase, or round this one can't read.
    var unsupportedState: some View {
        OnlineNoticeView(
            symbol: "arrow.down.app",
            title: localized("common.error"),
            message: NetworkingError.unsupportedVersion.localizedDescription,
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
                    // Connectivity hero glyph; off-token size with no Dynamic Type match.
                    // swiftlint:disable:next no_inline_font
                    .font(.system(size: 42, weight: .bold))
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

    @ViewBuilder
    var playingContent: some View {
        if !allPlayersSubmittedWords {
            if isAutomaticWords {
                OnlineWaitingView(message: localized("online.preparingGame"))
            } else if roomManager.currentPlayer?.hasSubmittedWords == true {
                OnlineWaitingView(message: localized("online.waitingForOthers"))
            } else {
                OnlineWordInputView()
            }
        } else {
            gamePhaseContent
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

    func initializeGameIfNeeded() {
        guard !hasInitializedGame,
              let room,
              room.gameState == nil else { return }
        hasInitializedGame = true

        Task {
            do {
                let words = try await roomManager.getWords()
                try await gameSyncManager.initializeGame(room: room, words: words)
            } catch {
                hasInitializedGame = false
            }
        }
    }

    /// Host-only. In automatic mode the host generates the shared word pool
    /// from the bundled database once the game starts; `fillRandomWords` then
    /// atomically opens the submission gate for everyone, which triggers
    /// initialization. Retries transient write failures rather than stranding
    /// the room on the waiting screen; the atomic write makes retries safe
    /// (a failed attempt persists nothing, so no duplicate words).
    func generateWordsIfNeeded() {
        guard roomManager.isHost,
              isAutomaticWords,
              !hasGeneratedWords,
              room?.gameState == nil,
              !allPlayersSubmittedWords,
              let room = roomManager.room else { return }
        hasGeneratedWords = true

        let count = max(1, room.settings.wordsPerPlayer * room.players.count)
        let hostId = roomManager.currentPlayerId ?? ""
        // Built once: every retry sends the same ids.
        let words = WordDatabase.randomWords(count: count).map { OnlineWord(text: $0, addedByPlayerId: hostId) }
        Task {
            for attempt in 1...3 {
                do {
                    try await roomManager.fillRandomWords(words)
                    return
                } catch {
                    guard attempt < 3 else {
                        hasGeneratedWords = false
                        return
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }
}
