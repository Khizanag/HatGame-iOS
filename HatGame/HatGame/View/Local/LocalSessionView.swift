//
//  LocalSessionView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

/// Phase-switching container for an active nearby-play session. Same shape
/// as `OnlineGameFlowView` (lobby → words → game phases → results) but the
/// underlying `RoomManager` is a `LocalRoomManager` backed by Multipeer.
struct LocalSessionView: View {
    @Environment(RoomManager.self) private var roomManager
    @Environment(GameSyncManager.self) private var gameSyncManager
    @Environment(LocalRoomManager.self) private var localRoomManager
    @Environment(Navigator.self) private var navigator

    @State private var hasInitializedGame: Bool = false
    @State private var hasGeneratedWords: Bool = false
    @State private var showHostLostAlert: Bool = false
    @State private var hasBeenConnected: Bool = false

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
            .onChange(of: localRoomManager.isConnected) { _, isConnected in
                if isConnected {
                    hasBeenConnected = true
                } else if hasBeenConnected, !localRoomManager.isHostInternal {
                    showHostLostAlert = true
                }
            }
            .alert("local.session.hostLost", isPresented: $showHostLostAlert) {
                Button("local.session.hostLost.action", role: .cancel) {
                    Task { try? await localRoomManager.leaveRoom() }
                    navigator.popToRoot()
                }
            } message: {
                Text(localized("local.session.hostLost.message"))
            }
    }

    private func initializeGameIfNeeded() {
        guard !hasInitializedGame,
              let room,
              room.gameState == nil else { return }
        hasInitializedGame = true

        Task {
            do {
                // For local: words are already in localRoomManager.words
                // (the host submitted on behalf of everyone via Multipeer).
                let words = localRoomManager.words
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

    /// Host-only. In automatic mode the host draws the shared word pool from
    /// the bundled database when the game starts; `fillRandomWords` broadcasts
    /// it and opens the submission gate for everyone, triggering initialization.
    private func generateWordsIfNeeded() {
        guard localRoomManager.isHostInternal,
              isAutomaticWords,
              !hasGeneratedWords,
              room?.gameState == nil,
              !allPlayersSubmittedWords,
              let room = localRoomManager.room else { return }
        hasGeneratedWords = true

        let count = max(1, room.settings.wordsPerPlayer * room.players.count)
        let texts = WordDatabase.randomWords(count: count)
        let hostId = localRoomManager.currentPlayerId ?? ""
        Task {
            for attempt in 1...3 {
                do {
                    try await localRoomManager.fillRandomWords(texts, hostPlayerId: hostId)
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

// MARK: - Sub-views
private extension LocalSessionView {
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
            connectingState.transition(.opacity)
        }
    }

    /// Shown while the snapshot from the host hasn't arrived yet — the
    /// MC handshake has fired but `roomSnapshot` is still in flight.
    var connectingState: some View {
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
                Image(systemName: "antenna.radiowaves.left.and.right")
                    // Connectivity hero glyph; off-token size with no Dynamic Type match.
                    // swiftlint:disable:next no_inline_font
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(DesignBook.Gradient.primary)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
            .accessibilityHidden(true)
            Text(localized("local.session.connecting"))
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
            Text(localized("local.session.connectingHint"))
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
}
