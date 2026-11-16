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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isGiveUpConfirmationPresented = false
    /// Whether opening the give-up alert paused a running clock, so Cancel resumes it.
    @State private var didPauseForGiveUp = false

    private var team: Team? { engine.state.currentTeam }
    private var tint: Color { team?.color ?? DesignBook.Color.Text.accent }
    private var isShowingPausedOverlay: Bool { engine.isPaused && !isGiveUpConfirmationPresented }

    /// At accessibility sizes the timer shrinks so the word card keeps its room.
    private var timerSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? 120 : 168 }

    var body: some View {
        content
            .accessibilityHidden(isShowingPausedOverlay)
            .navigationTitle(engine.state.round.title)
            .inlineNavigationTitle()
            .setDefaultBackground()
            .toolbar { gameToolbar }
            .onChange(of: engine.remainingSeconds) { _, seconds in
                playUrgencyHaptics(at: seconds)
                announceTimeLeft(at: seconds)
            }
            .alert(localized("game.giveUp.title"), isPresented: $isGiveUpConfirmationPresented) {
                giveUpAlertActions
            } message: {
                Text(localized("game.giveUp.confirmationMessage"))
            }
            .overlay {
                if isShowingPausedOverlay {
                    GamePausedOverlay(onResume: togglePause)
                        .transition(.opacity)
                        .accessibilityAddTraits(.isModal)
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
            .frame(width: timerSize, height: timerSize)
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
        // The turn is one fixed, non-scrolling screen; past this size the
        // timer, card, and buttons can no longer all fit.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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

    /// Side by side when both labels fit; stacked (Got It first) at large text sizes.
    var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignBook.Spacing.md) {
                skipButton
                gotItButton
            }
            VStack(spacing: DesignBook.Spacing.sm) {
                gotItButton
                skipButton
            }
        }
    }

    @ViewBuilder
    var skipButton: some View {
        if engine.state.settings.isSkippingEnabled {
            Button(action: skipCurrentWord) {
                Label(localized("game.skip"), systemImage: "arrow.uturn.forward")
                    .font(DesignBook.Font.title3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignBook.Spacing.sm)
            }
            .glassButtonStyle()
            .tint(DesignBook.Color.Status.warning)
            .disabled(!engine.canSkip)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .accessibilityIdentifier("game.skip")
        }
    }

    var gotItButton: some View {
        Button(action: markCurrentWordGuessed) {
            Label(localized("game.gotIt"), systemImage: "checkmark.circle.fill")
                .font(DesignBook.Font.title3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignBook.Spacing.sm)
        }
        .glassProminentButtonStyle()
        .tint(DesignBook.Color.Status.successFill)
        .disabled(engine.isPaused || engine.state.currentWord == nil)
        .keyboardShortcut(.rightArrow, modifiers: [])
        .accessibilityIdentifier("game.gotIt")
    }

    /// Give Up is a text item — a flag can't say what it does. Escape pauses
    /// and resumes, since it should never end the turn.
    @ToolbarContentBuilder
    var gameToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(localized("game.giveUp.button"), action: presentGiveUpConfirmation)
                .accessibilityIdentifier("game.giveUp")
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: togglePause) {
                Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
            }
            .accessibilityLabel(Text(pauseButtonTitle))
            .help(pauseButtonTitle)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("game.pause")
        }
    }

    var pauseButtonTitle: String {
        engine.isPaused ? localized("game.timer.resume") : localized("game.timer.pause")
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

    /// Speaks the time left at 10 s and 5 s, so a VoiceOver user who can't
    /// watch the ring still hears the turn running out.
    func announceTimeLeft(at seconds: Int) {
        guard !engine.isPaused, seconds == 10 || seconds == 5 else { return }
        AccessibilityNotification.Announcement(localized("game.timer.accessibility.seconds \(seconds)")).post()
    }
}
