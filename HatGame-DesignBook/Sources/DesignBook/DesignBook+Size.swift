//
//  DesignBook+Size.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import SwiftUI

extension DesignBook {
    public enum Size {
        // MARK: - Button Sizes
        public static let buttonHeight: CGFloat = 56
        public static let floatingButtonSize: CGFloat = 56
        public static let pauseButtonWidth: CGFloat = 216
        public static let touchTargetSize: CGFloat = 44

        // MARK: - Corner Radius
        public static let cardCornerRadius: CGFloat = 20
        public static let smallCardCornerRadius: CGFloat = 12

        // MARK: - Icon Sizes
        public static let iconSize: CGFloat = 24
        public static let smallIconSize: CGFloat = 20
        public static let mediumIconSize: CGFloat = 32
        public static let largeIconSize: CGFloat = 48
        public static let extraLargeIconSize: CGFloat = 80

        // MARK: - Badge & Indicator Sizes
        public static let badgeSize: CGFloat = 24
        public static let colorSwatchSize: CGFloat = 44
        public static let playerNumberBadgeSize: CGFloat = 24
        public static let selectionIndicatorSize: CGFloat = 24
        public static let rankIndicatorWidth: CGFloat = 40

        // MARK: - Dot Indicators
        public static let dotSmall: CGFloat = 6
        public static let dotMedium: CGFloat = 8
        public static let dotLarge: CGFloat = 12

        // MARK: - Card & Circle Sizes
        public static let cardSmall: CGFloat = 50
        public static let cardMedium: CGFloat = 60
        public static let cardLarge: CGFloat = 70
        public static let cardXLarge: CGFloat = 80
        public static let cardMassive: CGFloat = 100

        // MARK: - Component-Specific Sizes
        public static let settingsIconBoxSize: CGFloat = 32
        public static let footerGradientHeight: CGFloat = 120

        // MARK: - Layout Widths
        /// Readable max width for a content column; centers the column on wide
        /// windows (macOS / large iPad). A no-op on phone-width windows.
        public static let maxContentWidth: CGFloat = 600
        /// Max width of the gameplay word card, kept comfortably square and
        /// proportional to the timer regardless of window width.
        public static let wordCardMaxWidth: CGFloat = 440
    }
}
