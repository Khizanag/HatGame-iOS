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

    @State private var hasInitializedGame: Bool = false
    @State private var hasGeneratedWords: Bool = false

    private var room: GameRoom? { roomManager.room }
    private var roomStatus: RoomStatus? { room?.status }
    private var gamePhase: GamePhase? { room?.gameState?.phase }
    private var isAutomaticWords: Bool { room?.settings.isAutomaticWords == true }

    private var allPlayersSubmittedWords: Bool {
        guard let players = room?.players, !players.isEmpty else { return false }
        return players.allSatisfy(\.hasSubmittedWords)
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
        switch roomStatus {
        case .waiting, .setup:
            RoomLobbyView().transition(.opacity)
        case .playing:
            playingContent.transition(.opacity)
        case .finished:
            OnlineResultsView().transition(.opacity)
        case nil:
            joiningState.transition(.opacity)
        }
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
                    .symbolEffect(.variableColor.iterative, options: .repeating)
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
        case nil: OnlineWaitingView(message: localized("online.preparingGame"))
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
                _ = try await gameSyncManager.initializeGame(
                    for: room.id,
                    teams: room.teams,
                    players: room.players,
                    words: words,
                    settings: room.settings
                )
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
        let texts = WordDatabase.randomWords(count: count)
        let hostId = roomManager.currentPlayerId ?? ""
        Task {
            for attempt in 1...3 {
                do {
                    try await roomManager.fillRandomWords(texts, hostPlayerId: hostId)
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
