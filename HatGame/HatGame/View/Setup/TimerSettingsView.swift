//
//  TimerSettingsView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct TimerSettingsView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedDuration: Int = GameDefaults.standard.roundDuration
    @State private var isSkippingEnabled: Bool = GameDefaults.standard.isSkippingEnabled
    @State private var skipPenalty: Int = GameDefaults.standard.skipPenalty
    @State private var hasLoadedConfiguration = false

    var body: some View {
        content
            .navigationTitle(localized("timerSettings.title"))
            .setDefaultStyle()
            .onAppear(perform: loadConfiguration)
    }
}

// MARK: - Components
private extension TimerSettingsView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                heroValueCard
                controlsCard
                rulesCard
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
                HeroNumberText(value: selectedDuration)
                Text(localized("timerSettings.unit.seconds"))
                    .font(DesignBook.Font.displayMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            // The slider and stepper below speak the value; the hero would repeat it.
            .accessibilityHidden(true)

            Text(localized("timerSettings.headerTitle"))
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Text(localized("timerSettings.headerDescription"))
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
                durationSlider
                durationStepper
                timerTags
            }
        }
    }

    var durationSlider: some View {
        Slider(
            value: durationBinding,
            in: 5...120,
            step: 5
        )
        .tint(DesignBook.Color.Text.accent)
        .accessibilityLabel(Text(localized("timerSettings.turnLength")))
        .accessibilityValue(Text(durationValue))
    }

    var durationStepper: some View {
        Stepper(value: $selectedDuration, in: 5...120, step: 5) {
            Text(localized("timerSettings.turnLength"))
                .font(DesignBook.Font.subheadline)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
        .accessibilityValue(Text(durationValue))
    }

    var durationValue: String {
        localized("timerSettings.seconds \(selectedDuration)")
    }

    var timerTags: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            LegendTag(
                title: localized("timerSettings.legend.lightning"),
                range: "5-30s",
                isHighlighted: selectedDuration.isBetween(5, and: 30)
            )
            LegendTag(
                title: localized("timerSettings.legend.classic"),
                range: "60s",
                isHighlighted: selectedDuration == 60
            )
            LegendTag(
                title: localized("timerSettings.legend.marathon"),
                range: "90-120s",
                isHighlighted: selectedDuration.isBetween(90, and: 120)
            )
        }
    }

    var rulesCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                skippingToggle
                if isSkippingEnabled {
                    Divider()
                    SkipPenaltyRow(penalty: $skipPenalty)
                }
            }
            .animation(
                DesignBook.Motion.respectingReducedMotion(.snappy, reduceMotion: reduceMotion),
                value: isSkippingEnabled
            )
        }
    }

    var skippingToggle: some View {
        Toggle(isOn: $isSkippingEnabled) {
            HStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: "arrow.uturn.forward")
                    .font(DesignBook.IconFont.small)
                    .foregroundStyle(DesignBook.Color.Status.warning)
                    .frame(width: DesignBook.Size.touchTargetSize, height: DesignBook.Size.touchTargetSize)
                    .background(Circle().fill(DesignBook.Color.Status.warning.opacity(0.15)))
                    .decorativeHeroSizing()

                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    Text(localized("timerSettings.allowSkipping.title"))
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    Text(localized("timerSettings.allowSkipping.description"))
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    var continueButton: some View {
        PrimaryButton(title: localized("common.buttons.continue"), icon: "arrow.right.circle.fill") {
            handleContinue()
        }
        .keyboardShortcut(.defaultAction)
    }

    var durationBinding: Binding<Double> {
        Binding(
            get: { Double(selectedDuration) },
            set: { newValue in
                let stepped = Int(newValue)
                if stepped != selectedDuration {
                    selectedDuration = stepped
                }
            }
        )
    }

    /// Starts from the game's configuration, which carries the user's defaults.
    func loadConfiguration() {
        guard !hasLoadedConfiguration else { return }
        hasLoadedConfiguration = true
        selectedDuration = gameManager.configuration.roundDuration
        isSkippingEnabled = gameManager.configuration.isSkippingEnabled
        skipPenalty = gameManager.configuration.skipPenalty
    }

    func handleContinue() {
        gameManager.configuration.roundDuration = selectedDuration
        gameManager.configuration.isSkippingEnabled = isSkippingEnabled
        gameManager.configuration.skipPenalty = skipPenalty
        navigator.push(.wordSource)
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
        TimerSettingsView()
    }
    .environment(Navigator())
    .environment(GameManager())
}
