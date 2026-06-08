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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let appConfiguration = AppConfiguration.shared

    @State private var selectedWordCount: Int = 10

    var body: some View {
        content
            .navigationTitle(localized("wordSettings.title"))
            .setDefaultStyle()
            .onAppear {
                selectedWordCount = appConfiguration.defaultWordsPerPlayer
            }
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
        .safeAreaInset(edge: .bottom) {
            continueButton
                .paddingHorizontalDefault()
                .withFooterGradient()
        }
    }

    var heroValueCard: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.xs) {
                Text("\(selectedWordCount)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(selectedWordCount)))
                    .animation(reduceMotion ? nil : DesignBook.Motion.snappy, value: selectedWordCount)
                    .foregroundStyle(DesignBook.Gradient.primary)
                Image(systemName: "text.bubble.fill")
                    .font(DesignBook.Font.title2)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }

            Text(localized("wordSettings.headerTitle"))
                .font(DesignBook.Font.headline)
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
            step: 1,
            onEditingChanged: { editing in
                if !editing {
                    DesignBook.Haptics.selection()
                }
            }
        )
        .tint(DesignBook.Color.Text.accent)
    }

    var stepper: some View {
        Stepper(value: $selectedWordCount, in: 3...20) {
            Text(localized("common.tapOrHoldToAdjust"))
                .font(DesignBook.Font.caption)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
        .onChange(of: selectedWordCount) { _, _ in
            DesignBook.Haptics.selection()
        }
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
            DesignBook.Haptics.tap()
            handleContinue()
        }
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

    func handleContinue() {
        gameManager.configuration.wordsPerPlayer = selectedWordCount
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
