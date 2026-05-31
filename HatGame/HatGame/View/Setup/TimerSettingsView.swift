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

    private let appConfiguration = AppConfiguration.shared

    @State private var selectedDuration: Int = 60
    @State private var isSkippingEnabled: Bool = true

    var body: some View {
        content
            .navigationTitle(String(localized: "timerSettings.title"))
            .setDefaultStyle()
            .onAppear {
                selectedDuration = appConfiguration.defaultRoundDuration
                isSkippingEnabled = appConfiguration.defaultSkippingEnabled
            }
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
        .safeAreaInset(edge: .bottom) {
            continueButton
                .paddingHorizontalDefault()
                .withFooterGradient()
        }
    }

    var heroValueCard: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.xs) {
                Text("\(selectedDuration)")
                    // Unique hero numeral; no Dynamic Type text-style token matches this size.
                    // swiftlint:disable:next no_inline_font
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(selectedDuration)))
                    .animation(reduceMotion ? nil : DesignBook.Motion.snappy, value: selectedDuration)
                    .foregroundStyle(DesignBook.Gradient.primary)
                Text("s")
                    .font(DesignBook.Font.title)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }

            Text("timerSettings.headerTitle")
                .font(DesignBook.Font.headline)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Text("timerSettings.headerDescription")
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
            step: 5,
            onEditingChanged: { editing in
                if !editing {
                    DesignBook.Haptics.selection()
                }
            }
        )
        .tint(DesignBook.Color.Text.accent)
    }

    var durationStepper: some View {
        Stepper(value: $selectedDuration, in: 5...120, step: 5) {
            Text(String(localized: "common.tapOrHoldToAdjust"))
                .font(DesignBook.Font.caption)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
        .onChange(of: selectedDuration) { _, _ in
            DesignBook.Haptics.selection()
        }
    }

    var timerTags: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            LegendTag(
                title: String(localized: "timerSettings.legend.lightning"),
                range: "5-30s",
                isHighlighted: selectedDuration.isBetween(5, and: 30)
            )
            LegendTag(
                title: String(localized: "timerSettings.legend.classic"),
                range: "60s",
                isHighlighted: selectedDuration == 60
            )
            LegendTag(
                title: String(localized: "timerSettings.legend.marathon"),
                range: "90-120s",
                isHighlighted: selectedDuration.isBetween(90, and: 120)
            )
        }
    }

    var rulesCard: some View {
        GameCard {
            Toggle(isOn: $isSkippingEnabled) {
                HStack(spacing: DesignBook.Spacing.md) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(DesignBook.IconFont.small)
                        .foregroundStyle(DesignBook.Color.Status.warning)
                        .frame(width: DesignBook.Size.touchTargetSize, height: DesignBook.Size.touchTargetSize)
                        .background(Circle().fill(DesignBook.Color.Status.warning.opacity(0.15)))

                    VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                        Text("timerSettings.allowSkipping.title")
                            .font(DesignBook.Font.headline)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                        Text("timerSettings.allowSkipping.description")
                            .font(DesignBook.Font.caption)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .tint(DesignBook.Color.Status.warning)
            .onChange(of: isSkippingEnabled) { _, _ in
                DesignBook.Haptics.selection()
            }
        }
    }

    var continueButton: some View {
        PrimaryButton(title: String(localized: "common.buttons.continue"), icon: "arrow.right.circle.fill") {
            DesignBook.Haptics.tap()
            handleContinue()
        }
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

    func handleContinue() {
        gameManager.configuration.roundDuration = selectedDuration
        gameManager.configuration.isSkippingEnabled = isSkippingEnabled
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
