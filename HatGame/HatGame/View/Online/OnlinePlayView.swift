//
//  OnlinePlayView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct OnlinePlayView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(RoomManager.self) private var roomManager
    @Environment(GameSyncManager.self) private var gameSyncManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var remainingSeconds: Int = 0
    @State private var timerTick: Timer?
    @State private var showingGiveUpConfirmation: Bool = false
    @State private var words: [String: OnlineWord] = [:]
    @State private var hasPlayedFinalWarning: Bool = false
    @State private var wordLoadFailed: Bool = false

    private var room: GameRoom? { roomManager.room }
    private var gameState: OnlineGameState? { room?.gameState }
    private var teams: [OnlineTeam] { room?.teams ?? [] }
    private var players: [OnlinePlayer] { room?.players ?? [] }

    private var currentTeam: OnlineTeam? {
        guard let state = gameState else { return nil }
        return teams[safe: state.currentTeamIndex]
    }

    private var isActivePlayer: Bool {
        gameState?.activePlayerId == roomManager.currentPlayerId
    }

    private var currentWord: OnlineWord? {
        guard let id = gameState?.currentWordId else { return nil }
        return words[id]
    }

    private var totalWordCount: Int { gameState?.allWordIds.count ?? 0 }
    private var remainingWordCount: Int { gameState?.remainingWordIds.count ?? 0 }

    private var explainerName: String {
        guard let id = gameState?.activePlayerId,
              let player = players.first(where: { $0.id == id }) else { return "" }
        return player.name
    }

    private var teamScoreThisRound: Int {
        guard let team = currentTeam, let state = gameState else { return 0 }
        return state.getScore(for: team.id, in: state.currentRound)
    }

    var body: some View {
        content
            .setDefaultBackground()
            .navigationBarBackButtonHidden()
            .toolbar { gameToolbar }
            .task(id: gameState?.currentWordId) {
                await loadWordsIfNeeded()
            }
            .onAppear { startTimerLoop() }
            .onDisappear { stopTimerLoop() }
            .onChange(of: gameState?.timerStartedAt) { _, _ in syncRemainingSeconds() }
            .onChange(of: gameState?.phase) { _, newPhase in
                if newPhase != .playing { stopTimerLoop() }
            }
            .onChange(of: gameState?.currentWordId) { _, newId in
                guard isActivePlayer, newId == nil, gameState?.phase == .playing else { return }
                endTurn()
            }
            .alert(localized("game.giveUp.title"), isPresented: $showingGiveUpConfirmation) {
                Button(localized("common.buttons.cancel"), role: .cancel) { }
                Button(localized("game.giveUp.button"), role: .destructive) { endTurn() }
            } message: {
                Text(localized("game.giveUp.confirmationMessage"))
            }
    }
}

// MARK: - Composition
private extension OnlinePlayView {
    @ViewBuilder
    var content: some View {
        if isActivePlayer {
            explainerContent
        } else if let team = currentTeam {
            OnlineSpectatorView(
                team: team,
                explainerName: explainerName,
                isOwnTeam: roomManager.currentPlayer?.teamId == team.id,
                remainingSeconds: remainingSeconds,
                totalSeconds: gameState?.roundDuration ?? 60,
                teamScore: teamScoreThisRound,
                totalWords: totalWordCount,
                remainingWords: remainingWordCount
            )
        } else {
            ProgressView()
        }
    }

    var explainerContent: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            CircularTimerView(
                remainingSeconds: remainingSeconds,
                totalSeconds: gameState?.roundDuration ?? 60,
                isPaused: false,
                tint: tint
            )
            .frame(width: 168, height: 168)
            .padding(.top, DesignBook.Spacing.sm)

            wordSection
            actionRow

            GameProgressFooter(
                passed: totalWordCount - remainingWordCount,
                total: totalWordCount,
                tint: tint
            )
        }
        .padding(.top, DesignBook.Spacing.lg)
        .paddingHorizontalDefault()
    }

    var tint: Color {
        guard let team = currentTeam else { return DesignBook.Color.Text.accent }
        return Color(hex: team.colorHex) ?? DesignBook.Color.Text.accent
    }

    /// Whether the host enabled skipping for this game at all (frozen into the
    /// synced game state). Old games without the flag default to allowed.
    var isSkippingAllowed: Bool {
        gameState?.isSkippingEnabled ?? true
    }

    /// Whether the skip control is actionable right now: allowed AND more than
    /// one word remains (parity with the offline rule).
    var isSkipEnabled: Bool {
        isSkippingAllowed && remainingWordCount > 1
    }

    @ViewBuilder
    var wordSection: some View {
        if let word = currentWord {
            WordCard(
                word: word.text,
                teamTint: tint,
                onGuessed: markGuessed,
                onSkip: skipCurrentWord,
                isSkipEnabled: isSkipEnabled
            )
            .id(word.id)
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.92)),
                    removal: .opacity
                )
            )
        } else if wordLoadFailed {
            wordLoadErrorCard
        } else {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(DesignBook.Color.Background.card)
                .frame(maxWidth: DesignBook.Size.wordCardMaxWidth)
                .aspectRatio(1.05, contentMode: .fit)
                .opacity(0.4)
        }
    }

    var wordLoadErrorCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: "wifi.exclamationmark")
                    .font(DesignBook.IconFont.large)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                Text(localized("onlinePlay.wordsFailed"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                SecondaryButton(title: localized("common.tryAgain"), icon: "arrow.clockwise") {
                    retryLoadWords()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignBook.Spacing.md)
        }
    }

    var actionRow: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            if isSkippingAllowed {
                Button(action: skipCurrentWord) {
                    Label("game.skip", systemImage: "arrow.uturn.forward")
                        .font(DesignBook.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignBook.Spacing.sm)
                }
                .buttonStyle(.glass)
                .tint(DesignBook.Color.Status.warning)
                .disabled(!isSkipEnabled)
                .opacity(isSkipEnabled ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
                .keyboardShortcut(.leftArrow, modifiers: [])
            }

            Button(action: markGuessed) {
                Label("game.gotIt", systemImage: "checkmark.circle.fill")
                    .font(DesignBook.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignBook.Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .tint(DesignBook.Color.Status.success)
            .disabled(currentWord == nil)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
    }

    @ToolbarContentBuilder
    var gameToolbar: some ToolbarContent {
        if isActivePlayer {
            ToolbarItem(placement: .cancellationAction) {
                Button { showingGiveUpConfirmation = true } label: {
                    Label("game.giveUp.button", systemImage: "flag")
                        .foregroundStyle(DesignBook.Color.Status.error)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
        }
    }
}

// MARK: - Timer
private extension OnlinePlayView {
    func syncRemainingSeconds() {
        guard let state = gameState else {
            remainingSeconds = 0
            return
        }
        guard let startedAt = state.timerStartedAt else {
            // Pre-turn: show the full duration so the ring sits at 100%.
            remainingSeconds = state.roundDuration
            return
        }
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        remainingSeconds = max(0, state.roundDuration - elapsed)
    }

    func startTimerLoop() {
        stopTimerLoop()
        hasPlayedFinalWarning = false
        syncRemainingSeconds()
        timerTick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
    }

    func stopTimerLoop() {
        timerTick?.invalidate()
        timerTick = nil
    }

    func tick() {
        guard gameState?.phase == .playing else { return }
        let previous = remainingSeconds
        syncRemainingSeconds()
        playUrgencyHaptics(from: previous, to: remainingSeconds)
        if previous > 0, remainingSeconds == 0 {
            SoundPlayer.shared.playTimeUp()
        }
        guard remainingSeconds == 0, isActivePlayer else { return }
        endTurn()
    }

    func playUrgencyHaptics(from previous: Int, to current: Int) {
        guard previous != current else { return }
        switch current {
        case 3 where !hasPlayedFinalWarning:
            DesignBook.Haptics.warning()
            hasPlayedFinalWarning = true
        case 1, 2:
            DesignBook.Haptics.tap()
        default:
            break
        }
    }
}

// MARK: - Words loading
private extension OnlinePlayView {
    func loadWordsIfNeeded() async {
        guard words.isEmpty else { return }
        do {
            let fetched = try await roomManager.getWords()
            for word in fetched {
                words[word.id] = word
            }
            wordLoadFailed = false
        } catch {
            wordLoadFailed = true
        }
    }

    func retryLoadWords() {
        wordLoadFailed = false
        DesignBook.Haptics.tap()
        Task { await loadWordsIfNeeded() }
    }
}

// MARK: - Actions
private extension OnlinePlayView {
    func markGuessed() {
        guard isActivePlayer,
              let roomId = room?.id,
              let state = gameState else { return }
        DesignBook.Haptics.confirm()
        Task {
            try? await gameSyncManager.markWordGuessed(roomId: roomId, gameState: state, teams: teams)
        }
    }

    func skipCurrentWord() {
        guard isActivePlayer,
              let roomId = room?.id,
              let state = gameState,
              isSkipEnabled else { return }
        DesignBook.Haptics.soft()
        Task {
            try? await gameSyncManager.skipWord(roomId: roomId, gameState: state)
        }
    }

    func endTurn() {
        guard isActivePlayer,
              let roomId = room?.id,
              let state = gameState else { return }
        stopTimerLoop()
        DesignBook.Haptics.rigid()
        Task {
            try? await gameSyncManager.endTurn(roomId: roomId, gameState: state)
        }
    }
}

// MARK: - Helpers
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
