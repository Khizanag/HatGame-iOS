//
//  HeroNumberText.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The big gradient number on the setup screens. Each digit rolls on its
/// own: up when the number grows, down when it shrinks.
///
/// Not `.numericText`, which clips a rolling digit to the line it sits on
/// and cut the hero's digits off at the top and bottom. And not a gradient
/// `foregroundStyle`, which clips text to its own frame: the gradient is drawn
/// through a mask with room around the digits, stretched to the number's own
/// frame so it looks the same as a plain fill.
struct HeroNumberText: View {
    let value: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shownValue: Int
    @State private var rollsUp = true

    /// How far a digit travels as it rolls in or out.
    @ScaledMetric(relativeTo: .largeTitle) private var rollDistance: CGFloat = 52
    /// Room around the digits for one rolling past the line, or fading out
    /// beside a number that has just lost a digit.
    @ScaledMetric(relativeTo: .largeTitle) private var overflow: CGFloat = 72

    init(value: Int) {
        self.value = value
        _shownValue = State(initialValue: value)
    }

    var body: some View {
        digits
            .hidden()
            .overlay {
                GeometryReader { proxy in
                    gradient(spanning: proxy.size)
                        .mask { digits.padding(overflow) }
                        .padding(-overflow)
                }
            }
            .onChange(of: value) { oldValue, newValue in
                roll(from: oldValue, to: newValue)
            }
    }
}

// MARK: - Subviews
private extension HeroNumberText {
    var digits: some View {
        HStack(spacing: 0) {
            ForEach(places, id: \.self) { place in
                ZStack {
                    Text(verbatim: "\(digit(at: place))")
                        .id(digit(at: place))
                        .transition(rollTransition)
                }
            }
        }
        .font(DesignBook.Font.heroNumber)
        .monospacedDigit()
        .lineLimit(1)
        // Past this the hero no longer fits beside its unit; the slider and
        // stepper below speak the value at any size.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// Place values, most significant first. The ones digit is place 0, so
    /// each digit keeps its identity when the number gains or loses one.
    var places: [Int] {
        Array((0..<String(shownValue).count).reversed())
    }

    func digit(at place: Int) -> Int {
        var remaining = shownValue
        for _ in 0..<place {
            remaining /= 10
        }
        return remaining % 10
    }

    var rollTransition: AnyTransition {
        let incoming = rollsUp ? rollDistance : -rollDistance
        return .asymmetric(
            insertion: .offset(y: incoming),
            removal: .offset(y: -incoming)
        )
        .combined(with: .opacity)
        .combined(with: .modifier(active: DigitBlur(radius: 6), identity: DigitBlur(radius: 0)))
    }

    /// `Gradient.primary` laid over a frame grown by `overflow` on every
    /// side, with its end points kept on the number's own corners.
    func gradient(spanning size: CGSize) -> LinearGradient {
        let width = size.width + overflow * 2
        let height = size.height + overflow * 2
        return LinearGradient(
            colors: DesignBook.Gradient.primaryColors,
            startPoint: UnitPoint(x: overflow / width, y: overflow / height),
            endPoint: UnitPoint(x: (overflow + size.width) / width, y: (overflow + size.height) / height)
        )
    }
}

// MARK: - Actions
private extension HeroNumberText {
    /// A digit leaves with the transition it last rendered with, so the
    /// direction lands one update before the value changes.
    func roll(from oldValue: Int, to newValue: Int) {
        guard !reduceMotion else {
            shownValue = newValue
            return
        }
        rollsUp = newValue > oldValue
        Task {
            withAnimation(DesignBook.Motion.snappy) {
                shownValue = newValue
            }
        }
    }
}

// MARK: - Digit blur
private struct DigitBlur: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}
