//
//  GameView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

/// The timed turn. Renders the engine's state and forwards intents; the clock,
/// scoring, and the end of the turn all live in `GameEngine`.
struct GameView: View {
    @Environment(GameEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isGiveUpConfirmationPresented = false
    /// Whether opening the give-up alert paused a running clock, so Cancel resumes it.
    @State private var didPauseForGiveUp = false

    private var team: Team? { engine.state.currentTeam }
    private var tint: Color { team?.color ?? DesignBook.Color.Text.accent }

    var body: some View {
        content
            .setDefaultBackground()
            .toolbar { gameToolbar }
            .onChange(of: engine.remainingSeconds) { _, seconds in
                playUrgencyHaptics(at: seconds)
            }
            .alert(localized("game.giveUp.title"), isPresented: $isGiveUpConfirmationPresented) {
                giveUpAlertActions
            } message: {
                Text(localized("game.giveUp.confirmationMessage"))
            }
            .overlay {
                if engine.isPaused, !isGiveUpConfirmationPresented {
                    GamePausedOverlay(onResume: togglePause)
                        .transition(.opacity)
                        .accessibilityIdentifier("game.pausedOverlay")
                }
            }
            .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: engine.isPaused)
    }
}

// MARK: - Subviews
private extension GameView {
    var content: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            if let team {
                GameHeaderBar(
                    round: engine.state.round,
                    team: team,
                    guessedCount: engine.state.turn?.guessedWordIds.count ?? 0
                )
            }

            CircularTimerView(
                remainingSeconds: engine.remainingSeconds,
                totalSeconds: engine.state.settings.roundDuration,
                isPaused: engine.isPaused,
                tint: tint
            )
            .frame(width: 168, height: 168)
            .padding(.top, DesignBook.Spacing.sm)

            wordSection

            actionButtons

            GameProgressFooter(
                passed: engine.state.words.count - engine.state.remainingWordCount,
                total: engine.state.words.count,
                tint: tint
            )
        }
        .padding(.top, DesignBook.Spacing.lg)
        .paddingHorizontalDefault()
    }

    @ViewBuilder
    var wordSection: some View {
        if let word = engine.state.currentWord {
            WordCard(
                word: word.text,
                teamTint: tint,
                onGuessed: markCurrentWordGuessed,
                onSkip: skipCurrentWord,
                isSkipEnabled: engine.canSkip
            )
            .id(word.id)
            .transition(
                .asymmetric(
                    insertion: reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)),
                    removal: .opacity
                )
            )
        } else {
            RoundedRectangle(cornerRadius: DesignBook.Size.heroCardCornerRadius, style: .continuous)
                .fill(DesignBook.Color.Background.card)
                .frame(maxWidth: DesignBook.Size.wordCardMaxWidth)
                .aspectRatio(1.05, contentMode: .fit)
                .opacity(0.4)
        }
    }

    var actionButtons: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            if engine.state.settings.isSkippingEnabled {
                Button(action: skipCurrentWord) {
                    Label("game.skip", systemImage: "arrow.uturn.forward")
                        .font(DesignBook.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignBook.Spacing.sm)
                }
                .buttonStyle(.glass)
                .tint(DesignBook.Color.Status.warning)
                .disabled(!engine.canSkip)
                .opacity(engine.canSkip ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .accessibilityIdentifier("game.skip")
            }

            Button(action: markCurrentWordGuessed) {
                Label("game.gotIt", systemImage: "checkmark.circle.fill")
                    .font(DesignBook.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignBook.Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .tint(DesignBook.Color.Status.success)
            .disabled(engine.isPaused || engine.state.currentWord == nil)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .accessibilityIdentifier("game.gotIt")
        }
    }

    @ToolbarContentBuilder
    var gameToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: presentGiveUpConfirmation) {
                Label("game.giveUp.button", systemImage: "flag")
                    .foregroundStyle(DesignBook.Color.Status.error)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("game.giveUp")
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: togglePause) {
                Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
            }
            .accessibilityLabel(
                engine.isPaused ? Text(localized("game.timer.resume")) : Text(localized("game.timer.pause"))
            )
            .keyboardShortcut("p", modifiers: [])
            .accessibilityIdentifier("game.pause")
        }
    }

    @ViewBuilder
    var giveUpAlertActions: some View {
        Button(localized("common.buttons.cancel"), role: .cancel, action: cancelGiveUp)
        Button(localized("game.giveUp.button"), role: .destructive) {
            engine.giveUp()
        }
    }
}

// MARK: - Actions
private extension GameView {
    func markCurrentWordGuessed() {
        guard !engine.isPaused, engine.state.currentWord != nil else { return }
        DesignBook.Haptics.confirm()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.smooth) {
            engine.guess()
        }
    }

    func skipCurrentWord() {
        guard engine.canSkip else { return }
        DesignBook.Haptics.soft()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.smooth) {
            engine.skip()
        }
    }

    func togglePause() {
        DesignBook.Haptics.tap()
        engine.togglePause()
    }

    /// Pauses the clock while the alert is up, so time can't run out (and end
    /// the turn a second time) behind the confirmation.
    func presentGiveUpConfirmation() {
        didPauseForGiveUp = !engine.isPaused
        engine.pause()
        isGiveUpConfirmationPresented = true
    }

    func cancelGiveUp() {
        if didPauseForGiveUp {
            engine.resume()
        }
        didPauseForGiveUp = false
    }

    /// Final-seconds urgency: one warning at 3 s, ticks at 2 s and 1 s.
    func playUrgencyHaptics(at seconds: Int) {
        guard !engine.isPaused else { return }
        switch seconds {
        case 3:
            DesignBook.Haptics.warning()
        case 1, 2:
            DesignBook.Haptics.tap()
        default:
            break
        }
    }
}
