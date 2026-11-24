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
    private var tint: Color { team?.color ?? TeamDefaultColorGenerator.defaultColors[0] }
    private var isShowingPausedOverlay: Bool { engine.isPaused && !isGiveUpConfirmationPresented }

    /// At accessibility sizes the timer shrinks so the word card keeps its room.
    private var timerSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? 120 : 168 }

    var body: some View {
        adaptiveContent
            .accessibilityHidden(isShowingPausedOverlay)
            .navigationTitle(engine.state.round.title)
            .inlineNavigationTitle()
            .setDefaultBackground()
            .toolbar { gameToolbar }
            .onChange(of: engine.remainingSeconds) { _, seconds in
                announceTimeLeft(at: seconds)
            }
            .haptic(.success, trigger: guessedCount) { old, new in new > old }
            .haptic(.selection, trigger: skippedCount) { old, new in new > old }
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
                GameHeaderBar(team: team, points: engine.state.turnPoints)
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
    }

    /// The turn fits on one screen; at the largest text sizes, where it
    /// can't, it scrolls instead of clipping (constitution article 15).
    var adaptiveContent: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
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
                .wordCardFrame()
                .opacity(DesignBook.Opacity.disabled)
        }
    }

    /// Side by side normally; stacked at accessibility sizes, where two
    /// half-width buttons would truncate their labels. One glass container,
    /// so the pair reads as one control group.
    var actionButtons: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DesignBook.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DesignBook.Spacing.md))
        return GlassContainer(spacing: DesignBook.Spacing.md) {
            layout {
                skipButton
                gotItButton
            }
        }
    }

    @ViewBuilder
    var skipButton: some View {
        if engine.state.settings.isSkippingEnabled {
            Button(action: skipCurrentWord) {
                Label(SkipPenaltyRow.skipTitle(penalty: skipPenalty), systemImage: "arrow.uturn.forward")
                    .font(DesignBook.Font.title3)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignBook.Spacing.sm)
            }
            .glassButtonStyle()
            .tint(DesignBook.Color.Status.warning)
            .disabled(!engine.canSkip)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .accessibilityLabel(Text(SkipPenaltyRow.skipAccessibilityLabel(penalty: skipPenalty)))
            .accessibilityIdentifier("game.skip")
        }
    }

    var gotItButton: some View {
        Button(action: markCurrentWordGuessed) {
            Label(localized("game.gotIt"), systemImage: "checkmark.circle.fill")
                .font(DesignBook.Font.title3)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignBook.Spacing.sm)
        }
        .glassProminentButtonStyle()
        .tint(DesignBook.Color.Status.successFill)
        .disabled(engine.isPaused || engine.state.currentWord == nil)
        .keyboardShortcut(.rightArrow, modifiers: [])
        .accessibilityIdentifier("game.gotIt")
    }

    /// Give Up stays text, the HIG's exception for an action no symbol says:
    /// a flag reads as Report, and an xmark would read as leaving the game.
    /// Escape pauses and resumes, since it should never end the turn.
    @ToolbarContentBuilder
    var gameToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(localized("game.giveUp.button"), action: presentGiveUpConfirmation)
                .accessibilityIdentifier("game.giveUp")
        }

        // The clock's control carries its readout, "❚❚ 0:42", so the eye has
        // one place to look (constitution article 29).
        ToolbarItem(placement: .primaryAction) {
            Button(action: togglePause) {
                Label {
                    Text(verbatim: clockText)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                } icon: {
                    Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                }
                .labelStyle(.titleAndIcon)
            }
            .accessibilityLabel(Text(pauseButtonTitle))
            .help(pauseButtonTitle)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("game.pause")
        }
    }

    var skipPenalty: Int {
        engine.state.settings.skipPenalty
    }

    var clockText: String {
        let seconds = max(0, engine.remainingSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
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
    var guessedCount: Int {
        engine.state.turn?.guessedWordIds.count ?? 0
    }

    var skippedCount: Int {
        engine.state.turn?.skippedCount ?? 0
    }

    func markCurrentWordGuessed() {
        guard !engine.isPaused, engine.state.currentWord != nil else { return }
        withAnimation(reduceMotion ? nil : DesignBook.Motion.smooth) {
            engine.guess()
        }
    }

    func skipCurrentWord() {
        guard engine.canSkip else { return }
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

    /// Speaks the time left at 10 s and 5 s, so a VoiceOver user who can't
    /// watch the ring still hears the turn running out.
    func announceTimeLeft(at seconds: Int) {
        guard !engine.isPaused, seconds == 10 || seconds == 5 else { return }
        AccessibilityNotification.Announcement(localized("game.timer.accessibility.seconds \(seconds)")).post()
    }
}
