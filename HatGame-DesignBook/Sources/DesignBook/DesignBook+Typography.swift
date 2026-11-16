//
//  DesignBook+Typography.swift
//  HatGame
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
    /// Text fonts. Every token scales with Dynamic Type: text-style tokens
    /// directly, display and hero tokens by anchoring a design size to the text
    /// style whose growth curve they follow (see `scaled(_:relativeTo:weight:design:)`).
    public enum Font {
        // MARK: - Display
        /// 56 pt bold, scales with Large Title.
        public static let largeTitle = scaled(56, relativeTo: .largeTitle, weight: .bold)
        /// 42 pt bold, scales with Large Title.
        public static let title = scaled(42, relativeTo: .largeTitle, weight: .bold)
        /// 32 pt bold, scales with Title.
        public static let title2 = scaled(32, relativeTo: .title, weight: .bold)

        // MARK: - Hero numerals
        /// 96 pt bold — the big value on the word-count and timer setup screens.
        public static let heroNumber = scaled(96, relativeTo: .largeTitle, weight: .bold)
        /// 64 pt bold — a turn's guessed-word count.
        public static let heroScore = scaled(64, relativeTo: .largeTitle, weight: .bold)
        /// 38 pt bold with monospaced digits — the turn countdown.
        public static let timer = scaled(38, relativeTo: .largeTitle, weight: .bold).monospacedDigit()
        /// 44 pt bold monospaced — a room code shown for others to type.
        public static let roomCode = scaled(44, relativeTo: .largeTitle, weight: .bold, design: .monospaced)

        // MARK: - Text styles
        public static let title3 = SwiftUI.Font.system(.title, design: .rounded).weight(.semibold)
        public static let headline = SwiftUI.Font.system(.title3, design: .rounded).weight(.semibold)
        public static let callout = SwiftUI.Font.system(.title2, design: .rounded).weight(.semibold)
        public static let body = SwiftUI.Font.system(.body, design: .rounded).weight(.regular)
        public static let bodyBold = SwiftUI.Font.system(.body, design: .rounded).weight(.semibold)
        /// 18 pt bold, scales with Body.
        public static let subheadlineBold = scaled(18, relativeTo: .body, weight: .bold)
        public static let caption = SwiftUI.Font.system(.subheadline, design: .rounded).weight(.regular)
        public static let captionBold = SwiftUI.Font.system(.subheadline, design: .rounded).weight(.semibold)
        /// 14 pt bold, scales with Footnote.
        public static let footnoteBold = scaled(14, relativeTo: .footnote, weight: .bold)
        public static let smallCaption = SwiftUI.Font.system(.caption, design: .rounded).weight(.semibold)

        /// A font of `size` points at the default text size that grows and
        /// shrinks with Dynamic Type along `textStyle`'s curve.
        public static func scaled(
            _ size: CGFloat,
            relativeTo textStyle: SwiftUI.Font.TextStyle,
            weight: SwiftUI.Font.Weight = .regular,
            design: SwiftUI.Font.Design = .rounded
        ) -> SwiftUI.Font {
            SwiftUI.Font.system(textStyle, design: design, weight: weight)
                .scaled(by: size / defaultPointSize(of: textStyle))
        }
    }

    /// SF Symbol and emoji glyph sizes; all scale with Dynamic Type.
    public enum IconFont {
        public static let small = Font.scaled(20, relativeTo: .title3)
        public static let medium = Font.scaled(24, relativeTo: .title2)
        public static let large = Font.scaled(32, relativeTo: .title)
        /// 40 pt bold — a hero symbol inside a status disc.
        public static let hero = Font.scaled(40, relativeTo: .largeTitle, weight: .bold)
        public static let extraLarge = Font.scaled(48, relativeTo: .largeTitle)
        /// 60 pt bold — the symbol in a connectivity menu hero.
        public static let display = Font.scaled(60, relativeTo: .largeTitle, weight: .bold)
        public static let emoji = Font.scaled(80, relativeTo: .largeTitle)
        /// 88 pt — the home screen's hat.
        public static let emojiLarge = Font.scaled(88, relativeTo: .largeTitle)

        /// A symbol of `size` points that scales with `textStyle`, for glyphs
        /// sized by their container (icon tiles, badges).
        public static func sized(
            _ size: CGFloat,
            relativeTo textStyle: SwiftUI.Font.TextStyle = .body,
            weight: SwiftUI.Font.Weight = .regular
        ) -> SwiftUI.Font {
            Font.scaled(size, relativeTo: textStyle, weight: weight)
        }
    }
}

// MARK: - Default text-style sizes
private extension DesignBook.Font {
    /// The point size `textStyle` resolves to at the default (Large) content
    /// size on this platform — the anchor that `scaled` multiplies from.
    static func defaultPointSize(of textStyle: SwiftUI.Font.TextStyle) -> CGFloat {
        #if canImport(UIKit)
        UIFont.preferredFont(
            forTextStyle: textStyle.platformTextStyle,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        )
        .pointSize
        #else
        NSFont.preferredFont(forTextStyle: textStyle.platformTextStyle).pointSize
        #endif
    }
}

// MARK: - TextStyle bridging
#if canImport(UIKit)
private typealias PlatformTextStyle = UIFont.TextStyle
#else
private typealias PlatformTextStyle = NSFont.TextStyle
#endif

private extension SwiftUI.Font.TextStyle {
    var platformTextStyle: PlatformTextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}
