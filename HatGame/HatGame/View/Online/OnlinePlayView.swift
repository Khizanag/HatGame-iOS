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
    @State private var showingGiveUpConfirmation: Bool = false
    @State private var words: [String: OnlineWord] = [:]
    @State private var hasPlayedFinalWarning: Bool = false
    @State private var wordLoadFailed: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var error: Error?

    private var room: GameRoom? { roomManager.room }
    private var gameState: OnlineGameState? { room?.gameState }
    private var teams: [OnlineTeam] { room?.teams ?? [] }
    private var players: [OnlinePlayer] { room?.players ?? [] }

    private var currentTeam: OnlineTeam? {
        gameState.flatMap { OnlineGameRules.currentTeam($0, teams: teams) }
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
            // A new turn start restarts the countdown; leaving the view or
            // the turn cancels it.
            .task(id: gameState?.timerStartedAt) {
                await runCountdown()
            }
            .alert(localized("game.giveUp.title"), isPresented: $showingGiveUpConfirmation) {
                Button(localized("common.buttons.cancel"), role: .cancel) { }
                Button(localized("game.giveUp.button"), role: .destructive) { giveUp() }
            } message: {
                Text(localized("game.giveUp.confirmationMessage"))
            }
            .alert(localized("common.error"), isPresented: errorBinding) {
                Button(localized("common.gotIt")) { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
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
                totalSeconds: gameState.map(OnlineGameRules.turnDuration) ?? 60,
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
                totalSeconds: gameState.map(OnlineGameRules.turnDuration) ?? 60,
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
                .disabled(!isSkipEnabled || isSubmitting)
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
            .disabled(currentWord == nil || isSubmitting)
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
        guard let deadline = OnlineGameRules.deadline(state) else {
            // Pre-turn: show the full duration so the ring sits at 100%.
            remainingSeconds = OnlineGameRules.turnDuration(state)
            return
        }
        // Whole seconds rounded up, so the clock never sits on 0 while the
        // turn is still running.
        remainingSeconds = max(0, Int(deadline.timeIntervalSince(roomManager.now).rounded(.up)))
    }

    /// Ticks four times a second so the display flips close to each whole
    /// second; the remaining time always comes from the deadline, never
    /// from counting ticks.
    func runCountdown() async {
        hasPlayedFinalWarning = false
        syncRemainingSeconds()
        while gameState?.phase == .playing {
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            tick()
        }
    }

    func tick() {
        guard gameState?.phase == .playing else { return }
        let previous = remainingSeconds
        syncRemainingSeconds()
        playUrgencyHaptics(from: previous, to: remainingSeconds)
        if previous > 0, remainingSeconds == 0 {
            SoundPlayer.shared.playTimeUp()
        }
        guard remainingSeconds == 0, isActivePlayer || isCoveringStalledTurn else { return }
        // Retried on every tick until the turn leaves `.playing`, so a failed
        // write cannot strand the room at zero.
        perform(.endTurn, surfacesErrors: false)
    }

    /// The host closes a turn its explainer left running well past zero —
    /// a backgrounded or disconnected device never sends its own end.
    var isCoveringStalledTurn: Bool {
        guard roomManager.canActAsHost, let state = gameState else { return false }
        return OnlineGameRules.isStalled(state, now: roomManager.now)
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
        guard isActivePlayer, !isSubmitting, let wordId = gameState?.currentWordId else { return }
        DesignBook.Haptics.confirm()
        perform(.markGuessed(wordId: wordId))
    }

    func skipCurrentWord() {
        guard isActivePlayer, !isSubmitting, isSkipEnabled, let wordId = gameState?.currentWordId else { return }
        DesignBook.Haptics.soft()
        perform(.skip(wordId: wordId))
    }

    func giveUp() {
        guard isActivePlayer else { return }
        DesignBook.Haptics.rigid()
        perform(.endTurn)
    }

    /// One write in flight at a time: a second tap while the first is
    /// pending is dropped here, and one that slips through is rejected by
    /// the rules because the word has already moved on.
    func perform(_ action: GameAction, surfacesErrors: Bool = true) {
        guard !isSubmitting, let room, let playerId = roomManager.currentPlayerId else { return }
        isSubmitting = true
        Task {
            do {
                try await gameSyncManager.perform(action, room: room, playerId: playerId)
            } catch {
                if surfacesErrors { self.error = error }
            }
            isSubmitting = false
        }
    }
}
