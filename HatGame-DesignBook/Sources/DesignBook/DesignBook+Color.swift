//
//  DesignBook+Color.swift
//  DesignBook Package
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import SwiftUI

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

        public enum Status {
            public static let success = SwiftUI.Color(.Status.success)
            public static let error = SwiftUI.Color(.Status.error)
            public static let warning = SwiftUI.Color(.Status.warning)
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
