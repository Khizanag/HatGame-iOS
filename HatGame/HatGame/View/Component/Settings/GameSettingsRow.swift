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
    /// Spells out the value with its unit or a word, such as "30 seconds" or
    /// "None", from a String Catalog key so plurals and word order hold.
    var format: ((Int) -> String)?

    private var formattedValue: String {
        format?(value) ?? "\(value)"
    }

    var body: some View {
        content
    }
}

// MARK: - Layout
private extension GameSettingsRow {
    /// Title, value, and stepper on one line while they fit; stacked when
    /// they don't, so nothing clips at any text size (constitution article 15).
    @ViewBuilder
    var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                inline
                stacked
            }
        }
    }

    var inline: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack(spacing: DesignBook.Spacing.sm) {
                titleLabel
                    .fixedSize()
                Spacer(minLength: DesignBook.Spacing.sm)
                valueLabel
                    .fixedSize()
            }
        }
    }

    var stacked: some View {
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
    }

    var titleLabel: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignBook.IconFont.small)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .frame(width: iconWidth)

            Text(title)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
        }
    }

    var valueLabel: some View {
        Text(formattedValue)
            .font(DesignBook.Font.title3)
            .foregroundStyle(DesignBook.Color.Text.primary)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .animation(reduceMotion ? nil : DesignBook.Motion.snappy, value: value)
    }
}
