//
//  WordGenerationView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 31.05.26.
//

import DesignBook
import Navigation
import SwiftUI

/// Shown for the automatic word source: animates "drawing" words from the hat,
/// fills the game with random words from the bundled database, then continues.
struct WordGenerationView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .generating
    @State private var displayWord: String = ""
    @State private var wordBlur: Double = 0
    @State private var progress: Double = 0
    @State private var generatedCount: Int = 0
    @State private var hasStarted = false
    @State private var isHatFloating = false
    @State private var isSkipRequested = false
    @AccessibilityFocusState private var readyControlFocused: Bool

    private enum Phase {
        case generating
        case ready
        /// The word list for the current language is missing or empty.
        case unavailable
    }

    /// Total words to draw. Reached only after team setup, so there are always
    /// at least two teams of players; `max(1,)` is a defensive floor.
    private var targetCount: Int {
        let players = gameManager.configuration.teams.flatMap(\.players).count
        return max(1, gameManager.configuration.wordsPerPlayer * players)
    }

    var body: some View {
        content
            .navigationTitle(localized("wordGeneration.navTitle"))
            .inlineNavigationTitle()
            .setDefaultBackground()
            .navigationBarBackButtonHidden(phase == .generating)
            .hidesNavigationBar(phase == .generating)
            .haptic(.error, trigger: phase) { _, new in new == .unavailable }
            .haptic(.success, trigger: phase) { _, new in new == .ready }
            .task {
                await generateIfNeeded()
            }
    }
}

// MARK: - Layout
private extension WordGenerationView {
    @ViewBuilder
    var content: some View {
        if phase == .unavailable {
            unavailableContent
        } else {
            generationContent
        }
    }

    var unavailableContent: some View {
        VStack(spacing: DesignBook.Spacing.xl) {
            Spacer(minLength: 0)
            ContentUnavailableView {
                Label(localized("wordGeneration.unavailable.title"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(localized("wordGeneration.unavailable.message"))
            }
            Spacer(minLength: 0)
            PrimaryButton(title: localized("wordGeneration.unavailable.enterManually"), icon: "pencil") {
                gameManager.configuration.wordSource = .manual
                navigator.replace(with: .wordInput)
            }
        }
        .paddingHorizontalDefault()
        .padding(.bottom, DesignBook.Spacing.xl)
    }

    var generationContent: some View {
        VStack(spacing: DesignBook.Spacing.xl) {
            Spacer(minLength: 0)
            hatHero
                .decorativeHeroSizing()
            statusSection
            wordCard
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(DesignBook.Color.Text.accent)
                .padding(.horizontal, DesignBook.Spacing.xl)
                .opacity(phase == .generating ? 1 : 0)
                .accessibilityLabel(Text(localized("wordGeneration.title")))
            if phase == .generating {
                Text(localized("common.tapToSkip"))
                    .font(DesignBook.Font.footnote)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            }
            Spacer(minLength: 0)
            if phase == .ready, generatedCount > 0 {
                continueButton
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .paddingHorizontalDefault()
        .padding(.bottom, DesignBook.Spacing.xl)
        // The draw is decoration over instant work: a tap anywhere skips it.
        .contentShape(.rect)
        .onTapGesture(perform: skipDraw)
        .accessibilityAction(named: Text(localized("common.skip")), skipDraw)
    }

    var hatHero: some View {
        ZStack {
            HeroGlow(.wordDraw)

            Circle()
                .fill(DesignBook.Color.Background.card)
                .frame(width: DesignBook.Size.heroDisc, height: DesignBook.Size.heroDisc)
                .shadow(.large)

            Text(verbatim: "🎩")
                .font(DesignBook.IconFont.emoji)
                .offset(y: hatFloatOffset)
        }
        .overlay(alignment: .bottomTrailing) {
            if phase == .ready {
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignBook.IconFont.extraLarge)
                    .foregroundStyle(DesignBook.Color.Status.success)
                    .background(Circle().fill(DesignBook.Color.Background.primary))
                    .transition(.scale.combined(with: .opacity))
                    .offset(x: DesignBook.Spacing.xsPlus, y: DesignBook.Spacing.xsPlus)
            }
        }
        .accessibilityHidden(true)
    }

    var hatFloatOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        let amplitude = DesignBook.Size.hatFloatAmplitude
        return isHatFloating ? -amplitude : amplitude
    }

    var statusSection: some View {
        VStack(spacing: DesignBook.Spacing.xs) {
            Text(phase == .generating
                ? localized("wordGeneration.title")
                : localized("wordGeneration.ready"))
                .font(DesignBook.Font.displaySmall)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .contentTransition(.opacity)

            Text(phase == .generating
                ? localized("wordGeneration.subtitle")
                : localized("wordGeneration.count \(generatedCount)"))
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wordGeneration.status")
    }

    var wordCard: some View {
        Text(displayWord)
            .font(DesignBook.Font.displaySmall)
            .foregroundStyle(DesignBook.Color.Text.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .blur(radius: wordBlur)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignBook.Spacing.lg)
            .padding(.horizontal, DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .clipShape(.rect(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous))
            .opacity(phase == .generating ? 1 : 0)
            .contentTransition(.opacity)
            .accessibilityHidden(true)
    }

    var continueButton: some View {
        PrimaryButton(title: localized("common.buttons.continue"), icon: "arrow.right.circle.fill") {
            navigator.push(.randomization)
        }
        .keyboardShortcut(.defaultAction)
        .accessibilityFocused($readyControlFocused)
        .accessibilityHint(Text(localized("wordGeneration.count \(generatedCount)")))
    }
}

// MARK: - Generation
private extension WordGenerationView {
    /// Draws a sequence of words, each materializing out of a blur so the
    /// generation is visible, then fills the hat. Reduce Motion keeps the
    /// reveal but swaps the blur for a calm cross-fade through fewer words.
    /// Runs as the view's task, so leaving the screen cancels it.
    func generateIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        let pool = WordDatabase.words
        guard !pool.isEmpty else {
            phase = .unavailable
            return
        }

        if !reduceMotion {
            withAnimation(DesignBook.Motion.hatBob) {
                isHatFloating = true
            }
        }

        // The full draw plays once per session; later games get a short one.
        let isShort = reduceMotion || SessionAnimations.hasPlayedWordDraw
        SessionAnimations.hasPlayedWordDraw = true
        let drawCount = isShort ? 5 : 14
        let interval = reduceMotion ? DesignBook.Motion.reducedDrawInterval : DesignBook.Motion.drawInterval
        drawWord(from: pool)
        for draw in 2...drawCount {
            guard (try? await Task.sleep(for: interval)) != nil else {
                hasStarted = false
                return
            }
            if isSkipRequested { break }
            drawWord(from: pool)
            withAnimation(reduceMotion ? nil : DesignBook.Motion.drawProgress) {
                progress = Double(draw) / Double(drawCount)
            }
        }
        finish(from: pool)

        // Move VoiceOver to the now-actionable Continue button once it is on screen.
        guard (try? await Task.sleep(for: .milliseconds(100))) != nil else { return }
        readyControlFocused = true
    }

    func skipDraw() {
        guard phase == .generating else { return }
        isSkipRequested = true
    }

    /// Draws one random word, sharpening it into focus from a blur — or a calm
    /// opacity cross-fade under Reduce Motion.
    func drawWord(from words: [String]) {
        if reduceMotion {
            withAnimation(DesignBook.Motion.standard) {
                displayWord = words.randomElement() ?? ""
            }
        } else {
            displayWord = words.randomElement() ?? ""
            wordBlur = DesignBook.Size.drawnWordBlur
            withAnimation(DesignBook.Motion.sharpen) {
                wordBlur = 0
            }
        }
    }

    func finish(from pool: [String]) {
        gameManager.fillRandomWords(count: targetCount, from: pool)
        generatedCount = gameManager.configuration.words.count
        withAnimation(reduceMotion ? nil : DesignBook.Motion.smooth) {
            progress = 1
            phase = .ready
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        WordGenerationView()
    }
    .environment(Navigator())
    .environment(GameManager())
}
