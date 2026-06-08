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
    @State private var cycleTimer: Timer?
    @AccessibilityFocusState private var readyControlFocused: Bool

    private enum Phase { case generating, ready }

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
            .onAppear(perform: startIfNeeded)
            .onDisappear(perform: stopCycling)
    }
}

// MARK: - Layout
private extension WordGenerationView {
    var content: some View {
        VStack(spacing: DesignBook.Spacing.xl) {
            Spacer(minLength: 0)
            hatHero
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
                .font(DesignBook.Font.title2)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .contentTransition(.opacity)

            Text(phase == .generating
                ? localized("wordGeneration.subtitle")
                : String(format: localized("wordGeneration.count"), generatedCount))
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .combine)
    }

    var wordCard: some View {
        Text(displayWord)
            .font(DesignBook.Font.title2)
            .foregroundStyle(DesignBook.Color.Text.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .blur(radius: wordBlur)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignBook.Spacing.lg)
            .padding(.horizontal, DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
            .opacity(phase == .generating ? 1 : 0)
            .contentTransition(.opacity)
            .accessibilityHidden(true)
    }

    var continueButton: some View {
        PrimaryButton(title: localized("common.buttons.continue"), icon: "arrow.right.circle.fill") {
            DesignBook.Haptics.tap()
            navigator.push(.randomization)
        }
        .accessibilityFocused($readyControlFocused)
        .accessibilityHint(Text(String(format: localized("wordGeneration.count"), generatedCount)))
    }
}

// MARK: - Generation
private extension WordGenerationView {
    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isHatFloating = true
            }
        }

        let words = WordDatabase.words
        guard !words.isEmpty else {
            finish()
            return
        }

        // Draw a sequence of words, each materializing out of a blur so the
        // generation is visible. Reduce Motion keeps the reveal but swaps the
        // blur for a calm opacity cross-fade through fewer words.
        let drawCount = reduceMotion ? 5 : 14
        let interval = reduceMotion ? 0.34 : 0.16
        var draws = 1
        drawWord(from: words)

        cycleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            draws += 1
            drawWord(from: words)
            withAnimation(.linear(duration: interval)) {
                progress = min(1, Double(draws) / Double(drawCount))
            }
            if !reduceMotion, draws.isMultiple(of: 3) {
                Task { @MainActor in DesignBook.Haptics.selection() }
            }
            if draws >= drawCount {
                stopCycling()
                finish()
            }
        }
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

    func finish() {
        gameManager.fillRandomWords(count: targetCount)
        generatedCount = gameManager.configuration.words.count
        Task { @MainActor in DesignBook.Haptics.success() }
        withAnimation(reduceMotion ? nil : DesignBook.Motion.smooth) {
            progress = 1
            phase = .ready
        }
        // Move VoiceOver to the now-actionable Continue button once it is on screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            readyControlFocused = true
        }
    }

    func stopCycling() {
        cycleTimer?.invalidate()
        cycleTimer = nil
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
