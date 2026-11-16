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
            Spacer(minLength: 0)
            if phase == .ready, generatedCount > 0 {
                continueButton
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .paddingHorizontalDefault()
        .padding(.bottom, DesignBook.Spacing.xl)
    }

    var hatHero: some View {
        ZStack {
            Circle()
                .fill(DesignBook.Gradient.primary)
                .frame(width: 168, height: 168)
                .blur(radius: 36)
                .opacity(DesignBook.Opacity.semiTransparent)

            Circle()
                .fill(DesignBook.Color.Background.card)
                .frame(width: 136, height: 136)
                .shadow(.large)

            Text(verbatim: "🎩")
                .font(DesignBook.IconFont.emoji)
                .offset(y: reduceMotion ? 0 : (isHatFloating ? -8 : 8))
        }
        .overlay(alignment: .bottomTrailing) {
            if phase == .ready {
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignBook.IconFont.extraLarge)
                    .foregroundStyle(DesignBook.Color.Status.success)
                    .background(Circle().fill(DesignBook.Color.Background.primary))
                    .transition(.scale.combined(with: .opacity))
                    .offset(x: 6, y: 6)
            }
        }
        .accessibilityHidden(true)
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
    }

    var wordCard: some View {
        Text(displayWord)
            .font(DesignBook.Font.displaySmall)
            .foregroundStyle(DesignBook.Color.Text.accent)
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
            DesignBook.Haptics.error()
            phase = .unavailable
            return
        }

        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isHatFloating = true
            }
        }

        let drawCount = reduceMotion ? 5 : 14
        let interval: Duration = reduceMotion ? .milliseconds(340) : .milliseconds(160)
        drawWord(from: pool)
        for draw in 2...drawCount {
            guard (try? await Task.sleep(for: interval)) != nil else {
                hasStarted = false
                return
            }
            drawWord(from: pool)
            withAnimation(reduceMotion ? nil : .linear(duration: 0.16)) {
                progress = Double(draw) / Double(drawCount)
            }
        }
        finish(from: pool)

        // Move VoiceOver to the now-actionable Continue button once it is on screen.
        guard (try? await Task.sleep(for: .milliseconds(100))) != nil else { return }
        readyControlFocused = true
    }

    /// Draws one random word, sharpening it into focus from a blur — or a calm
    /// opacity cross-fade under Reduce Motion.
    func drawWord(from words: [String]) {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) {
                displayWord = words.randomElement() ?? ""
            }
        } else {
            displayWord = words.randomElement() ?? ""
            wordBlur = 16
            withAnimation(.easeOut(duration: 0.34)) {
                wordBlur = 0
            }
        }
    }

    func finish(from pool: [String]) {
        gameManager.fillRandomWords(count: targetCount, from: pool)
        generatedCount = gameManager.configuration.words.count
        DesignBook.Haptics.success()
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
