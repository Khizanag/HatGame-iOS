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

    let icon: String
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var suffix: String?

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: icon)
                    .font(DesignBook.IconFont.small)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .frame(width: DesignBook.Size.iconSize)

                Text(title)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                Spacer(minLength: DesignBook.Spacing.sm)

                Text(valueText)
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(reduceMotion ? nil : DesignBook.Motion.snappy, value: value)
            }
        }
        .onChange(of: value) { _, _ in
            DesignBook.Haptics.selection()
        }
    }

    private var valueText: String {
        suffix.map { "\(value) \($0)" } ?? "\(value)"
    }
}
