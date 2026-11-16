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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showHostLostAlert: Bool = false
    @State private var hasBeenConnected: Bool = false
    /// The host chose to start with the words already submitted.
    @State private var startsWithSubmittedWords: Bool = false

    private var room: GameRoom? { roomManager.room }
    private var roomStatus: RoomStatus? { room?.status }
    private var gamePhase: GamePhase? { room?.gameState?.phase }
    private var isAutomaticWords: Bool { room?.settings.isAutomaticWords == true }

    private var allPlayersSubmittedWords: Bool {
        room.map(RoomRules.allWordsSubmitted) ?? false
    }

    /// Only the host's device runs setup on nearby: it holds the room.
    private var setupStep: GameSetupStep? {
        guard localRoomManager.isHostInternal, let room, let playerId = roomManager.currentPlayerId else { return nil }
        return RoomRules.pendingSetupStep(in: room, for: playerId, startsWithSubmittedWords: startsWithSubmittedWords)
    }

    private var startWithSubmittedWords: (() -> Void)? {
        guard localRoomManager.isHostInternal,
              room.map(RoomRules.canStartWithSubmittedWords) == true else { return nil }
        return { startsWithSubmittedWords = true }
    }

    var body: some View {
        content
            .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: roomStatus)
            .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: gamePhase)
            .task(id: setupStep) {
                await OnlineGameSetup.run(setupStep, roomManager: roomManager, gameSyncManager: gameSyncManager)
            }
            .onChange(of: localRoomManager.isConnected) { _, isConnected in
                if isConnected {
                    hasBeenConnected = true
                } else if hasBeenConnected, !localRoomManager.isHostInternal {
                    showHostLostAlert = true
                }
            }
            .alert(localized("local.session.hostLost"), isPresented: $showHostLostAlert) {
                Button(localized("local.session.hostLost.action"), role: .cancel, action: leaveSession)
            } message: {
                Text(localized("local.session.hostLost.message"))
            }
    }
}

// MARK: - Sub-views
private extension LocalSessionView {
    @ViewBuilder
    var content: some View {
        if localRoomManager.connectionState == .unsupported || room?.isSupported == false {
            unsupportedState.transition(.opacity)
        } else if localRoomManager.connectionState == .closed {
            closedState.transition(.opacity)
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
                connectingState.transition(.opacity)
            }
        }
    }

    /// This device and the host run different protocol or data versions;
    /// either one may be the older build.
    var unsupportedState: some View {
        OnlineNoticeView(
            symbol: "arrow.down.app",
            title: localized("local.session.versionMismatch.title"),
            message: localized("local.session.versionMismatch"),
            actionTitle: localized("local.session.hostLost.action"),
            action: leaveSession
        )
    }

    /// The host refused this device, or never answered its hello.
    var closedState: some View {
        OnlineNoticeView(
            symbol: "door.left.hand.closed",
            title: localized("local.session.hostLost"),
            message: localRoomManager.rejection.map { NetworkErrorMessage.message(for: $0) }
                ?? localized("local.session.hostLost.message"),
            actionTitle: localized("local.session.hostLost.action"),
            action: leaveSession
        )
    }

    func leaveSession() {
        Task { try? await localRoomManager.leaveRoom() }
        navigator.popToRoot()
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
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
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

    /// A game state, once written, wins over everything else: a returning
    /// guest, or one who never submitted before the host started, goes
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
}
