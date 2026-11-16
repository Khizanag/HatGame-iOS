//
//  HeroNumberText.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The big gradient number on the setup screens, rolling between values.
///
/// A gradient `foregroundStyle` clips text to its own frame, which cuts the
/// digits off while `.numericText` rolls them past the line or fades out a
/// dropped digit after the frame has already narrowed. So the gradient is
/// drawn through a mask that leaves room around the glyphs, and is stretched
/// to match the number's own frame, so it looks the same as a plain fill.
struct HeroNumberText: View {
    let value: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// About one hero digit: room for a digit rolling past the line or
    /// fading out beside a number that has just lost a digit.
    private let overflow: CGFloat = 64

    var body: some View {
        number
            .hidden()
            .overlay {
                GeometryReader { proxy in
                    gradient(spanning: proxy.size)
                        .mask { number.padding(overflow) }
                        .padding(-overflow)
                }
            }
    }
}

// MARK: - Subviews
private extension HeroNumberText {
    var number: some View {
        Text(verbatim: "\(value)")
            .font(DesignBook.Font.heroNumber)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .contentTransition(.numericText(value: Double(value)))
            .animation(reduceMotion ? nil : DesignBook.Motion.snappy, value: value)
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
