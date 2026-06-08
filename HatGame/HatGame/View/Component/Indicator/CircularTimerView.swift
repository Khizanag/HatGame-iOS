//
//  CircularTimerView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import DesignBook
import SwiftUI

/// Circular ring timer with progress, glowing urgency state, and large readable time.
struct CircularTimerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let remainingSeconds: Int
    let totalSeconds: Int
    let isPaused: Bool
    /// Tint used for the active progress (typically the current team color).
    let tint: Color

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        let value = Double(remainingSeconds) / Double(totalSeconds)
        return min(max(value, 0), 1)
    }

    private var isUrgent: Bool {
        remainingSeconds > 0 && remainingSeconds <= 5
    }

    private var displayColor: Color {
        if isUrgent {
            DesignBook.Color.Status.error
        } else if isPaused {
            DesignBook.Color.Text.tertiary
        } else {
            tint
        }
    }

    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var accessibilityTimeLabel: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return minutes > 0
            ? String(format: localized("game.timer.accessibility.minutesSeconds"), minutes, seconds)
            : String(format: localized("game.timer.accessibility.seconds"), seconds)
    }

    var body: some View {
        ZStack {
            trackRing
            progressRing
            timeLabel
        }
        .scaleEffect(isUrgent && !reduceMotion ? 1.04 : 1.0)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.45).repeatForever(autoreverses: true),
            value: isUrgent
        )
    }
}

// MARK: - Subviews
private extension CircularTimerView {
    var trackRing: some View {
        Circle()
            .stroke(
                DesignBook.Color.Text.tertiary.opacity(DesignBook.Opacity.light),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
    }

    var progressRing: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                displayColor,
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            .shadow(color: displayColor.opacity(isUrgent ? 0.5 : 0.15), radius: isUrgent ? 12 : 6)
    }

    var timeLabel: some View {
        VStack(spacing: 0) {
            Text(formattedTime)
                // Hero countdown numeral; unique size with no Dynamic Type token.
                // swiftlint:disable:next no_inline_font
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(displayColor)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : DesignBook.Motion.snappy, value: remainingSeconds)
                .accessibilityLabel(accessibilityTimeLabel)

            if isPaused {
                Text(localized("game.timer.paused"))
                    .font(DesignBook.Font.smallCaption)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        CircularTimerView(remainingSeconds: 42, totalSeconds: 60, isPaused: false, tint: .blue)
            .frame(width: 180, height: 180)
        CircularTimerView(remainingSeconds: 4, totalSeconds: 60, isPaused: false, tint: .orange)
            .frame(width: 180, height: 180)
        CircularTimerView(remainingSeconds: 30, totalSeconds: 60, isPaused: true, tint: .blue)
            .frame(width: 180, height: 180)
    }
    .padding()
    .background(DesignBook.Color.Background.primary)
}
