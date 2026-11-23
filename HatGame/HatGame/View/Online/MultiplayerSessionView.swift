//
//  MultiplayerSessionView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

/// The phase router shared by online and nearby sessions: lobby → word
/// entry → game phases → results, plus the host's setup work. It reads the
/// `RoomManager` and `GameSyncManager` in the environment, so it runs on
/// either transport; each flow supplies its connecting copy, its terminal
/// screens, and which of its devices may act for the host.
struct MultiplayerSessionView: View {
    /// A session that cannot continue.
    enum Terminal {
        case closed
        case unsupported
    }

    /// What the first-load screen says before the first snapshot arrives.
    struct Connecting {
        let symbol: String
        let title: String
        let hint: String
    }

    @Environment(RoomManager.self) private var roomManager
    @Environment(GameSyncManager.self) private var gameSyncManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let transport: NetworkErrorMessage.Transport
    let terminal: Terminal?
    /// Whether this device runs the host's setup work once the game starts.
    let runsSetup: Bool
    /// Whether this device may start before every player has submitted.
    let canStartEarly: Bool
    let connecting: Connecting
    let closedNotice: OnlineNoticeView
    let unsupportedNotice: OnlineNoticeView

    /// The host chose to start with the words already submitted.
    @State private var startsWithSubmittedWords: Bool = false
    @State private var isLeaveConfirmationPresented: Bool = false
    @State private var isLeaving: Bool = false
    @State private var leaveError: (any Error)?

    private var room: GameRoom? { roomManager.room }
    private var roomStatus: RoomStatus? { room?.status }
    private var gamePhase: GamePhase? { room?.gameState?.phase }
    private var isAutomaticWords: Bool { room?.settings.isAutomaticWords == true }

    private var allPlayersSubmittedWords: Bool {
        room.map(RoomRules.allWordsSubmitted) ?? false
    }

    /// The host-side setup this device still owes the room, if any.
    private var setupStep: GameSetupStep? {
        guard runsSetup, let room, let playerId = roomManager.currentPlayerId else { return nil }
        return RoomRules.pendingSetupStep(in: room, for: playerId, startsWithSubmittedWords: startsWithSubmittedWords)
    }

    /// Offered to whoever can act as host while someone is still typing.
    private var startWithSubmittedWords: (() -> Void)? {
        guard canStartEarly, room.map(RoomRules.canStartWithSubmittedWords) == true else { return nil }
        return { startsWithSubmittedWords = true }
    }

    var body: some View {
        content
            .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: roomStatus)
            .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: gamePhase)
            .task(id: setupStep) {
                await OnlineGameSetup.run(setupStep, roomManager: roomManager, gameSyncManager: gameSyncManager)
            }
            // The system Back button (and the swipe that mirrors it) would
            // pop this screen without leaving the room, so every exit goes
            // through Leave, which tells the other devices.
            .navigationBarBackButtonHidden()
            .toolbar { leaveToolbar }
            .confirmationDialog(
                localized("lobby.leave.title"),
                isPresented: $isLeaveConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(localized("lobby.leave.confirm"), role: .destructive, action: leaveRoom)
                Button(localized("common.buttons.cancel"), role: .cancel) { }
            } message: {
                Text(leaveMessage)
            }
            .errorAlert($leaveError, title: localized("error.title.leaveRoom"), transport: transport, retry: leaveRoom)
    }
}

// MARK: - Leaving
private extension MultiplayerSessionView {
    /// A turn in progress keeps its own controls (Give Up); a terminal
    /// notice carries its own way out.
    var showsLeaveControl: Bool {
        terminal == nil && !(roomStatus == .playing && gamePhase == .playing)
    }

    /// Nothing is lost by leaving before the room loads or after the game ends.
    var leavesWithoutConfirmation: Bool {
        roomStatus == nil || roomStatus == .finished || gamePhase == .finished
    }

    @ToolbarContentBuilder
    var leaveToolbar: some ToolbarContent {
        if showsLeaveControl {
            CloseToolbarItem(accessibilityLabel: localized("session.leave")) {
                if leavesWithoutConfirmation {
                    leaveRoom()
                } else {
                    isLeaveConfirmationPresented = true
                }
            }
        }
    }

    /// What leaving costs, which depends on the phase and the transport: an
    /// online host's lobby closes for everyone, while a game in progress
    /// carries on without the leaver; a nearby host holds the room, so
    /// leaving ends it in any phase.
    var leaveMessage: String {
        let isInLobby = roomStatus?.isLobby ?? true
        switch transport {
        case .online:
            guard isInLobby else { return localized("session.leave.online.inGame") }
            return localized(roomManager.isHost ? "lobby.leave.hostMessage" : "lobby.leave.guestMessage")
        case .nearby:
            if roomManager.isHost { return localized("lobby.leave.hostMessage") }
            return localized(isInLobby ? "session.leave.nearby.lobby" : "session.leave.nearby.inGame")
        }
    }

    func leaveRoom() {
        guard !isLeaving else { return }
        isLeaving = true
        Task {
            do {
                try await roomManager.leaveRoom()
                navigator.popToRoot()
            } catch {
                leaveError = error
            }
            isLeaving = false
        }
    }
}

// MARK: - Composition
private extension MultiplayerSessionView {
    @ViewBuilder
    var content: some View {
        switch terminal {
        case .closed:
            closedNotice.transition(.opacity)
        case .unsupported:
            unsupportedNotice.transition(.opacity)
        case nil:
            roomContent
        }
    }

    @ViewBuilder
    var roomContent: some View {
        switch roomStatus {
        case .waiting, .setup:
            RoomLobbyView(transport: transport).transition(.opacity)
        case .playing:
            playingContent.transition(.opacity)
        case .finished:
            OnlineResultsView().transition(.opacity)
        case .unsupported:
            unsupportedNotice.transition(.opacity)
        case nil:
            connectingState.transition(.opacity)
        }
    }

    /// Shown until the first room snapshot arrives.
    var connectingState: some View {
        CenteredScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
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
                    Image(systemName: connecting.symbol)
                        .font(DesignBook.IconFont.sized(42, relativeTo: .largeTitle, weight: .bold))
                        .decorativeHeroSizing()
                        .foregroundStyle(DesignBook.Gradient.primary)
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                }
                .accessibilityHidden(true)
                Text(connecting.title)
                    .font(DesignBook.Font.title1)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .multilineTextAlignment(.center)
                Text(connecting.hint)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignBook.Spacing.lg)
            }
        }
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
        case .unsupported: unsupportedNotice
        case nil: OnlineWaitingView(message: localized("online.preparingGame"))
        }
    }
}
