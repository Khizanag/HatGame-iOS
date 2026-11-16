//
//  DesignBook+Contrast.swift
//  DesignBook Package
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

extension DesignBook {
    /// WCAG 2 contrast math on gamma-encoded sRGB components (0...1).
    public enum Contrast {
        /// The minimum contrast ratio for text (WCAG AA; HIG accessibility.md).
        public static let minimumTextRatio: Double = 4.5

        /// A gamma-encoded sRGB color without alpha.
        public struct RGB: Equatable, Sendable {
            public var red: Double
            public var green: Double
            public var blue: Double

            public init(red: Double, green: Double, blue: Double) {
                self.red = red
                self.green = green
                self.blue = blue
            }

            public static let black = RGB(red: 0, green: 0, blue: 0)
            public static let white = RGB(red: 1, green: 1, blue: 1)
        }

        /// WCAG relative luminance: 0 for black, 1 for white.
        public static func relativeLuminance(of color: RGB) -> Double {
            0.2126 * linearized(color.red)
                + 0.7152 * linearized(color.green)
                + 0.0722 * linearized(color.blue)
        }

        /// The WCAG contrast ratio between two colors, from 1 (identical) to 21.
        public static func ratio(between first: RGB, and second: RGB) -> Double {
            let firstLuminance = relativeLuminance(of: first)
            let secondLuminance = relativeLuminance(of: second)
            let lighter = max(firstLuminance, secondLuminance)
            let darker = min(firstLuminance, secondLuminance)
            return (lighter + 0.05) / (darker + 0.05)
        }

        /// `color` darkened (on a light background) or lightened (on a dark
        /// one) just far enough to reach `target` against `background`,
        /// keeping its hue. Returned unchanged when it already passes; when no
        /// mix can pass, the result is black or white.
        public static func adjusted(
            _ color: RGB,
            toRatio target: Double = minimumTextRatio,
            against background: RGB
        ) -> RGB {
            guard ratio(between: color, and: background) < target else { return color }
            let extreme: RGB = ratio(between: .black, and: background) >= ratio(between: .white, and: background)
                ? .black
                : .white
            var lower = 0.0
            var upper = 1.0
            for _ in 0..<24 {
                let middle = (lower + upper) / 2
                if ratio(between: mix(color, extreme, amount: middle), and: background) >= target {
                    upper = middle
                } else {
                    lower = middle
                }
            }
            return mix(color, extreme, amount: upper)
        }
    }
}

// MARK: - Helpers
private extension DesignBook.Contrast {
    static func linearized(_ component: Double) -> Double {
        component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
    }

    static func mix(_ color: RGB, _ other: RGB, amount: Double) -> RGB {
        RGB(
            red: color.red + (other.red - color.red) * amount,
            green: color.green + (other.green - color.green) * amount,
            blue: color.blue + (other.blue - color.blue) * amount
        )
    }
}
