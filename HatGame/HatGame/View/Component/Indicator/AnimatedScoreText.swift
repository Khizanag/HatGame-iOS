//
//  AnimatedScoreText.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import DesignBook
import SwiftUI

/// A text view that counts up to its target value when it appears or when the value changes.
struct AnimatedScoreText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let value: Int
    var font: Font = DesignBook.Font.title2
    var color: Color = DesignBook.Color.Text.primary
    var duration: Double = 0.9

    @State private var displayValue: Int = 0

    var body: some View {
        Text(verbatim: "\(displayValue)")
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(displayValue)))
            .onAppear { animate(to: value) }
            .onChange(of: value) { _, newValue in animate(to: newValue) }
    }
}

// MARK: - Helpers
private extension AnimatedScoreText {
    /// Rolls to the target in a single value change and lets `.numericText`
    /// drive the odometer animation natively (no per-step timer churn).
    func animate(to target: Int) {
        guard !reduceMotion else {
            displayValue = target
            return
        }
        withAnimation(.easeOut(duration: duration)) {
            displayValue = target
        }
    }
}

#Preview {
    AnimatedScoreText(value: 42, font: DesignBook.Font.largeTitle, color: .blue)
        .padding()
}
