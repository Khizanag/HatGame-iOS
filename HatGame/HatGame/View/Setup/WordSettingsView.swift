//
//  WordSettingsView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct WordSettingsView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator

    @State private var selectedWordCount: Int = GameDefaults.standard.wordsPerPlayer
    @State private var hasLoadedConfiguration = false

    var body: some View {
        content
            .navigationTitle(localized("wordSettings.title"))
            .setDefaultStyle()
            .onAppear(perform: loadConfiguration)
    }
}

// MARK: - Private
private extension WordSettingsView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                heroValueCard
                controlsCard
            }
            .paddingHorizontalDefault()
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .actionBar {
            continueButton
                .paddingHorizontalDefault()
        }
    }

    var heroValueCard: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.xs) {
                HeroNumberText(value: selectedWordCount)
                Image(systemName: "text.bubble.fill")
                    .font(DesignBook.Font.displaySmall)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            // The slider and stepper below speak the value; the hero would repeat it.
            .accessibilityHidden(true)

            Text(localized("wordSettings.headerTitle"))
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Text(localized("wordSettings.headerDescription"))
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignBook.Spacing.lg)
        }
        .padding(.top, DesignBook.Spacing.xl)
    }

    var controlsCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                slider
                stepper
                legendTags
            }
        }
    }

    var slider: some View {
        Slider(
            value: wordCountBinding,
            in: 3...20,
            step: 1
        )
        .tint(DesignBook.Color.Text.accent)
        .accessibilityLabel(Text(localized("wordSettings.wordsPerPlayer")))
        .accessibilityValue(Text(wordCountValue))
    }

    var stepper: some View {
        Stepper(value: $selectedWordCount, in: 3...20) {
            Text(localized("wordSettings.wordsPerPlayer"))
                .font(DesignBook.Font.subheadline)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
        .accessibilityValue(Text(wordCountValue))
    }

    var wordCountValue: String {
        localized("wordSettings.wordCount \(selectedWordCount)")
    }

    var legendTags: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            LegendTag(
                title: localized("wordSettings.legend.short"),
                range: "3-7",
                isHighlighted: selectedWordCount.isBetween(3, and: 7)
            )
            LegendTag(
                title: localized("wordSettings.legend.balanced"),
                range: "8-12",
                isHighlighted: selectedWordCount.isBetween(8, and: 12)
            )
            LegendTag(
                title: localized("wordSettings.legend.epic"),
                range: "13-20",
                isHighlighted: selectedWordCount.isBetween(13, and: 20)
            )
        }
    }

    var continueButton: some View {
        PrimaryButton(
            title: localized("common.buttons.continue"),
            icon: "arrow.right.circle.fill"
        ) {
            handleContinue()
        }
        .keyboardShortcut(.defaultAction)
    }

    var wordCountBinding: Binding<Double> {
        Binding(
            get: { Double(selectedWordCount) },
            set: { newValue in
                let stepped = Int(newValue)
                if stepped != selectedWordCount {
                    selectedWordCount = stepped
                }
            }
        )
    }

    /// Starts from the game's configuration, which carries the user's defaults.
    func loadConfiguration() {
        guard !hasLoadedConfiguration else { return }
        hasLoadedConfiguration = true
        selectedWordCount = gameManager.configuration.wordsPerPlayer
    }

    func handleContinue() {
        gameManager.configuration.wordsPerPlayer = selectedWordCount
        // Words typed under a higher count would leave players over the limit.
        gameManager.trimWords(toPerPlayer: selectedWordCount)
        navigator.push(.timerSettings)
    }
}

// MARK: - Private Extension
private extension Int {
    func isBetween(_ lower: Int, and upper: Int) -> Bool {
        self >= lower && self <= upper
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        WordSettingsView()
    }
    .environment(Navigator())
    .environment(GameManager())
}
