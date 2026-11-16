//
//  DesignBook+Color.swift
//  DesignBook Package
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DesignBook {
    public enum Color {
        public enum Background {
            public static let primary = SwiftUI.Color(.Background.primary)
            public static let secondary = SwiftUI.Color(.Background.secondary)
            public static let card = SwiftUI.Color(.Background.card)
        }

        public enum Text {
            public static let primary = SwiftUI.Color(.Text.primary)
            public static let secondary = SwiftUI.Color(.Text.secondary)
            public static let tertiary = SwiftUI.Color(.Text.tertiary)
            public static let accent = SwiftUI.Color(.Text.accent)
        }

        /// Status colors. The plain tokens are for text and glyphs on the app
        /// backgrounds (≥ 4.5:1); the `…Fill` tokens are for tinting prominent
        /// buttons, dark enough that their white label stays ≥ 4.5:1.
        public enum Status {
            public static let success = SwiftUI.Color(.Status.success)
            public static let error = SwiftUI.Color(.Status.error)
            public static let warning = SwiftUI.Color(.Status.warning)
            /// Tint for a prominent "success" button, such as Got It.
            public static let successFill = SwiftUI.Color(.Status.successFill)
            /// Tint for a prominent destructive button.
            public static let errorFill = SwiftUI.Color(.Status.errorFill)
        }

        /// Foreground for glyphs and text on the brand gradients and on dimmed
        /// overlays, which stay dark-saturated in both appearances.
        public static let onGradient = SwiftUI.Color.white

        /// Black or white — whichever has the higher WCAG contrast ratio
        /// against `background`. Use for content drawn on a team color.
        public static func onAccent(for background: SwiftUI.Color) -> SwiftUI.Color {
            let resolved = background.resolve(in: EnvironmentValues())
            let luminance = 0.2126 * resolved.linearRed
                + 0.7152 * resolved.linearGreen
                + 0.0722 * resolved.linearBlue
            let contrastWithWhite = 1.05 / (luminance + 0.05)
            let contrastWithBlack = (luminance + 0.05) / 0.05
            return contrastWithBlack > contrastWithWhite ? .black : .white
        }

        /// `teamColor` adjusted for use as text: darkened in light mode and
        /// lightened in dark mode just enough to reach 4.5:1 against
        /// `Background.primary`. It re-resolves for the current appearance,
        /// including Increase Contrast. Use it wherever a team color tints
        /// text (names, scores, timer digits); fills, dots, and rings keep the
        /// raw team color.
        public static func teamText(for teamColor: SwiftUI.Color) -> SwiftUI.Color {
            #if canImport(UIKit)
            SwiftUI.Color(uiColor: UIColor { traits in
                let team = UIColor(teamColor).resolvedColor(with: traits)
                let background = UIColor(Background.primary).resolvedColor(with: traits)
                return readable(team, against: background)
            })
            #elseif canImport(AppKit)
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                var result = NSColor(teamColor)
                appearance.performAsCurrentDrawingAppearance {
                    result = readable(NSColor(teamColor), against: NSColor(Background.primary))
                }
                return result
            })
            #endif
        }

        /// `color` with its alpha forced to 1. `onAccent(for:)` ignores alpha,
        /// so a fill behind its content must be opaque for the contrast to hold.
        /// An already-opaque color is returned as is, keeping any appearance variants.
        public static func opaque(_ color: SwiftUI.Color) -> SwiftUI.Color {
            var resolved = color.resolve(in: EnvironmentValues())
            guard resolved.opacity < 1 else { return color }
            resolved.opacity = 1
            return SwiftUI.Color(resolved)
        }
    }
}

// MARK: - Readable platform colors
#if canImport(UIKit)
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
private typealias PlatformColor = NSColor
#endif

private extension DesignBook.Color {
    /// `color` adjusted to reach the text contrast minimum against
    /// `background`; both must already be resolved for one appearance.
    static func readable(_ color: PlatformColor, against background: PlatformColor) -> PlatformColor {
        let (foreground, alpha) = components(of: color)
        let adjusted = DesignBook.Contrast.adjusted(foreground, against: components(of: background).rgb)
        return PlatformColor(red: adjusted.red, green: adjusted.green, blue: adjusted.blue, alpha: alpha)
    }

    static func components(of color: PlatformColor) -> (rgb: DesignBook.Contrast.RGB, alpha: CGFloat) {
        #if canImport(AppKit) && !canImport(UIKit)
        let color = color.usingColorSpace(.sRGB) ?? color
        #endif
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgb = DesignBook.Contrast.RGB(
            red: min(max(red, 0), 1),
            green: min(max(green, 0), 1),
            blue: min(max(blue, 0), 1)
        )
        return (rgb, alpha)
    }
}
