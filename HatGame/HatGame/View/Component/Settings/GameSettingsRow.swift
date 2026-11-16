//
//  GameSettingsRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.05.26.
//

import DesignBook
import SwiftUI

/// A labelled numeric row backed by a native `Stepper` for the −/+ control,
/// keeping the app's icon and animated value styling. Shared by
/// `DefaultsSettingsView`, `RoomCreationView` and `LocalHostSetupView` so the
/// flows look and behave the same.
struct GameSettingsRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var iconWidth = DesignBook.Size.iconSize

    let icon: String
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var suffix: String?

    private var formattedValue: String {
        suffix.map { "\(value) \($0)" } ?? "\(value)"
    }

    var body: some View {
        content
    }
}

// MARK: - Layout
private extension GameSettingsRow {
    @ViewBuilder
    var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
                titleLabel
                    .accessibilityHidden(true)
                HStack {
                    valueLabel
                        .accessibilityHidden(true)
                    Spacer(minLength: DesignBook.Spacing.sm)
                    Stepper(title, value: $value, in: range, step: step)
                        .labelsHidden()
                        .accessibilityValue(Text(formattedValue))
                }
            }
        } else {
            Stepper(value: $value, in: range, step: step) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    titleLabel
                    Spacer(minLength: DesignBook.Spacing.sm)
                    valueLabel
                }
            }
        }
    }

    var titleLabel: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignBook.IconFont.small)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
                .frame(width: iconWidth)

            Text(title)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
        }
    }

    var valueLabel: some View {
        Text(formattedValue)
            .font(DesignBook.Font.title3)
            .foregroundStyle(DesignBook.Color.Text.accent)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .animation(reduceMotion ? nil : DesignBook.Motion.snappy, value: value)
    }
}
