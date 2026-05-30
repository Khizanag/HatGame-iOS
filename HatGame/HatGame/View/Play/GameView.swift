//
//  GameView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct GameView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let round: GameRound

    @State private var timer: Timer?
    @State private var remainingSeconds: Int = 0
    @State private var showingGiveUpConfirmation: Bool = false
    @State private var isPaused: Bool = false
    @State private var guessedWords: [Word] = []
    @State private var hasPlayedFinalWarning: Bool = false

    var body: some View {
        content
            .setDefaultBackground()
            .navigationBarBackButtonHidden()
            .toolbar { gameToolbar }
            .onAppear(perform: handleAppear)
            .onDisappear(perform: stopTimer)
            .onChange(of: gameManager.currentWord) { _, newWord in
                handleCurrentWordChange(newWord)
            }
            .onChange(of: scenePhase) { _, phase in
                handleScenePhaseChange(phase)
            }
            .alert(String(localized: "game.giveUp.title"), isPresented: $showingGiveUpConfirmation) {
                giveUpAlertActions
            } message: {
                Text("game.giveUp.confirmationMessage")
            }
            .overlay {
                if isPaused {
                    GamePausedOverlay(onResume: togglePause)
                        .transition(.opacity)
                }
            }
    }
}

// MARK: - Subviews
private extension GameView {
    var content: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            GameHeaderBar(
                round: round,
                team: gameManager.currentTeam,
                guessedCount: guessedWords.count
            )

            CircularTimerView(
                remainingSeconds: remainingSeconds,
                totalSeconds: gameManager.configuration.roundDuration,
                isPaused: isPaused,
                tint: gameManager.currentTeam.color
            )
            .frame(width: 168, height: 168)
            .padding(.top, DesignBook.Spacing.sm)

            wordSection

            actionButtons

            GameProgressFooter(
                passed: gameManager.configuration.words.count - gameManager.remainingWordCount,
                total: gameManager.configuration.words.count,
                tint: gameManager.currentTeam.color
            )
        }
        .padding(.top, DesignBook.Spacing.lg)
        .paddingHorizontalDefault()
    }

    @ViewBuilder
    var wordSection: some View {
        if let word = gameManager.currentWord {
            WordCard(
                word: word.text,
                teamTint: gameManager.currentTeam.color,
                onGuessed: markCurrentWordGuessed,
                onSkip: skipCurrentWord,
                isSkipEnabled: isSkipAllowed && gameManager.remainingWordCount > 1
            )
            .id(word.id)
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.92)),
                    removal: .opacity
                )
            )
        } else {
            // Brief placeholder while transitioning to the turn results screen.
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(DesignBook.Color.Background.card)
                .aspectRatio(1.05, contentMode: .fit)
                .opacity(0.4)
        }
    }

    var actionButtons: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            if isSkipAllowed {
                Button(action: skipCurrentWord) {
                    Label("game.skip", systemImage: "arrow.uturn.forward")
                        .font(DesignBook.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignBook.Spacing.sm)
                }
                .buttonStyle(.glass)
                .tint(DesignBook.Color.Status.warning)
                .disabled(isSkipDisabled)
                .opacity(isSkipDisabled ? DesignBook.Opacity.disabled : DesignBook.Opacity.enabled)
            }

            Button(action: markCurrentWordGuessed) {
                Label("game.gotIt", systemImage: "checkmark.circle.fill")
                    .font(DesignBook.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignBook.Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .tint(DesignBook.Color.Status.success)
            .disabled(isPaused || gameManager.currentWord == nil)
        }
    }

    @ToolbarContentBuilder
    var gameToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                showingGiveUpConfirmation = true
            } label: {
                Label("game.giveUp.button", systemImage: "flag")
                    .foregroundStyle(DesignBook.Color.Status.error)
            }
            .buttonStyle(.plain)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: togglePause) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .padding(8)
                    .background {
                        Circle().fill(DesignBook.Color.Background.card)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPaused ? Text("game.timer.resume") : Text("game.timer.paused"))
        }
    }

    @ViewBuilder
    var giveUpAlertActions: some View {
        Button(String(localized: "common.buttons.cancel"), role: .cancel) {
            showingGiveUpConfirmation = false
        }
        Button(String(localized: "game.giveUp.button"), role: .destructive) {
            showingGiveUpConfirmation = false
            giveUpTurn()
        }
    }
}

// MARK: - Derived state
private extension GameView {
    /// Whether this game permits skipping at all (configured before the game starts).
    var isSkipAllowed: Bool {
        gameManager.configuration.isSkippingEnabled
    }

    var isSkipDisabled: Bool {
        gameManager.remainingWordCount <= 1 || isPaused || gameManager.currentWord == nil
    }
}

// MARK: - Lifecycle / state
private extension GameView {
    func handleAppear() {
        guard gameManager.currentWord != nil else {
            // Edge case: arrived with no word; nothing to play.
            stopTimer()
            return
        }
        startTimer()
    }

    /// Auto-pause an in-progress turn when the app leaves the foreground so the
    /// countdown can't run down while the player isn't looking. The player
    /// resumes manually from the pause overlay on return.
    func handleScenePhaseChange(_ phase: ScenePhase) {
        guard phase != .active, !isPaused, gameManager.currentWord != nil else { return }
        withAnimation(reduceMotion ? nil : DesignBook.Motion.smooth) {
            isPaused = true
        }
    }

    func handleCurrentWordChange(_ newWord: Word?) {
        guard newWord == nil else { return }
        // All words exhausted — preserve time and exit to turn results.
        stopTimer()
        gameManager.markPlayEndedWithTimeRemaining()
        if remainingSeconds > 0 {
            gameManager.saveRemainingTime(remainingSeconds, for: gameManager.currentTeam)
        }
        DesignBook.Haptics.success()
        navigator.push(.teamTurnResults(guessedWords: guessedWords, completionReason: .allWordsGuessed))
    }
}

// MARK: - Timer
private extension GameView {
    func startTimer() {
        stopTimer()
        isPaused = false
        hasPlayedFinalWarning = false
        remainingSeconds = gameManager.getRemainingTime(for: gameManager.currentTeam)
            ?? gameManager.configuration.roundDuration
        gameManager.clearRemainingTime(for: gameManager.currentTeam)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tickTimer()
        }
    }

    func tickTimer() {
        guard !isPaused else { return }
        guard remainingSeconds > 0 else {
            stopTimer()
            handleTimeExpired()
            return
        }
        remainingSeconds -= 1
        playUrgencyHaptics(at: remainingSeconds)
    }

    func playUrgencyHaptics(at seconds: Int) {
        // Final 3-second urgency feedback: one warning at 3s, ticks at 2s and 1s.
        switch seconds {
        case 3 where !hasPlayedFinalWarning:
            DesignBook.Haptics.warning()
            hasPlayedFinalWarning = true
        case 1, 2:
            DesignBook.Haptics.tap()
        default:
            break
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func togglePause() {
        DesignBook.Haptics.tap()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.smooth) {
            isPaused.toggle()
        }
    }
}

// MARK: - Actions
private extension GameView {
    func markCurrentWordGuessed() {
        guard !isPaused, let word = gameManager.currentWord else { return }
        DesignBook.Haptics.confirm()
        let animation = reduceMotion ? nil : DesignBook.Motion.smooth
        withAnimation(animation) {
            guessedWords.append(word)
            gameManager.commitWordGuess()
        }
    }

    func skipCurrentWord() {
        guard !isPaused, gameManager.remainingWordCount > 1 else { return }
        DesignBook.Haptics.soft()
        let animation = reduceMotion ? nil : DesignBook.Motion.smooth
        withAnimation(animation) {
            gameManager.skipCurrentWord()
        }
    }

    func giveUpTurn() {
        stopTimer()
        gameManager.markPlayEndedWithTimeOut()
        DesignBook.Haptics.rigid()
        navigator.push(.teamTurnResults(guessedWords: guessedWords, completionReason: .timeExpired))
    }

    func handleTimeExpired() {
        gameManager.markPlayEndedWithTimeOut()
        DesignBook.Haptics.error()
        SoundPlayer.shared.playTimeUp()
        navigator.push(.teamTurnResults(guessedWords: guessedWords, completionReason: .timeExpired))
    }
}
