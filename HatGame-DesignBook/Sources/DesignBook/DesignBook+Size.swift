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
        public static let floatingButtonSize: CGFloat = 56
        public static let pauseButtonWidth: CGFloat = 216
        public static let touchTargetSize: CGFloat = 44

        // MARK: - Corner Radius
        public static let cardCornerRadius: CGFloat = 20
        public static let smallCardCornerRadius: CGFloat = 12
        /// The gameplay word card and its placeholder.
        public static let heroCardCornerRadius: CGFloat = 32
        /// A paper slip swirling into the hat.
        public static let slipCornerRadius: CGFloat = 5
        /// A piece of confetti.
        public static let confettiCornerRadius: CGFloat = 2

        // MARK: - Icon Sizes
        public static let iconSize: CGFloat = 24
        public static let mediumIconSize: CGFloat = 32
        public static let largeIconSize: CGFloat = 48

        // MARK: - Badge & Indicator Sizes
        public static let badgeSize: CGFloat = 24
        public static let colorSwatchSize: CGFloat = 44
        public static let playerNumberBadgeSize: CGFloat = 24
        public static let selectionIndicatorSize: CGFloat = 24
        /// A team's colour shown as a small disc beside its name.
        public static let smallSwatchSize: CGFloat = 24
        /// A rank number on its disc in a standings list.
        public static let rankBadgeSize: CGFloat = 28
        /// The leading column a rank medal sits in.
        public static let medalColumnWidth: CGFloat = 30
        /// The check badge on a selected app-icon preview.
        public static let selectedBadgeSize: CGFloat = 28
        /// A player's status disc in a waiting list.
        public static let statusDiscSize: CGFloat = 36
        /// The colour stripe at the leading edge of a team row.
        public static let teamStripeWidth: CGFloat = 8

        // MARK: - Dot Indicators
        public static let dotSmall: CGFloat = 6
        public static let dotMedium: CGFloat = 8
        public static let dotRegular: CGFloat = 10
        public static let dotLarge: CGFloat = 12
        public static let dotExtraLarge: CGFloat = 14

        // MARK: - Strokes
        public static let hairline: CGFloat = 0.5
        public static let strokeThin: CGFloat = 1
        public static let strokeRegular: CGFloat = 1.5
        public static let strokeThick: CGFloat = 2
        /// The countdown timer's track and progress rings.
        public static let timerRingWidth: CGFloat = 10

        // MARK: - Hero
        /// The disc a hero glyph sits on, on a full-screen hero.
        public static let heroDisc: CGFloat = 136
        /// The disc under the filled hat before a game starts.
        public static let heroDiscMedium: CGFloat = 116
        /// The disc on a status hero, and the trophy disc.
        public static let heroDiscSmall: CGFloat = 96
        /// The disc on a setup screen's compact hero.
        public static let heroDiscCompact: CGFloat = 84
        /// The ring around the team whose turn is next, and a success emblem.
        public static let heroEmblem: CGFloat = 120
        /// The disc on a turn's results header.
        public static let heroBadge: CGFloat = 88
        /// The trophy disc on a revealed team card.
        public static let heroTrophy: CGFloat = 80
        /// How far a floating hero glyph drifts each way.
        public static let heroFloatAmplitude: CGFloat = 6
        /// How far the hat drifts each way while words are drawn.
        public static let hatFloatAmplitude: CGFloat = 8
        /// How blurred a drawn word starts before it sharpens.
        public static let drawnWordBlur: CGFloat = 16
        /// The space the hat-filling animation reserves.
        public static let hatFillStageHeight: CGFloat = 196
        /// The space the shuffling hat and its swirl of slips take up.
        public static let shuffleStageWidth: CGFloat = 300
        public static let shuffleStageHeight: CGFloat = 240
        /// The progress bar under the shuffle caption.
        public static let shuffleProgressWidth: CGFloat = 160
        /// A paper slip swirling into the hat.
        public static let slipWidth: CGFloat = 40
        public static let slipHeight: CGFloat = 26
        /// The glow over the upturned hat's opening.
        public static let hatOpeningGlowWidth: CGFloat = 76
        public static let hatOpeningGlowHeight: CGFloat = 18
        public static let hatOpeningGlowBlur: CGFloat = 8
        /// The countdown timer on an online turn.
        public static let onlineTimerSize: CGFloat = 168

        // MARK: - Card & Circle Sizes
        public static let cardSmall: CGFloat = 50
        public static let cardMedium: CGFloat = 60
        public static let cardLarge: CGFloat = 70
        public static let cardMassive: CGFloat = 100

        // MARK: - Layout Widths
        /// Readable max width for a content column; centers the column on wide
        /// windows (macOS / large iPad). A no-op on phone-width windows.
        public static let maxContentWidth: CGFloat = 600
        /// The one width a long-press preview is drawn at.
        public static let previewWidth: CGFloat = 320
        /// Max width of the gameplay word card, kept comfortably square and
        /// proportional to the timer regardless of window width.
        public static let wordCardMaxWidth: CGFloat = 440
        /// Width over height of the gameplay word card: just wider than square.
        public static let wordCardAspectRatio: CGFloat = 1.05

        // MARK: - App Icon Previews
        /// The current icon in its Settings row.
        public static let appIconPreviewSmall: CGFloat = 60
        /// An icon in the app-icon picker grid.
        public static let appIconPreviewLarge: CGFloat = 100
    }
}

// MARK: - Glow
extension DesignBook.Size {
    /// The blurred halo behind a hero's disc: how wide it is and how far it
    /// is blurred.
    public struct Glow: Sendable {
        public let diameter: CGFloat
        public let blur: CGFloat

        /// Home and the connectivity menus.
        public static let hero = Glow(diameter: 156, blur: 36)
        /// The hat filling with words.
        public static let hatFill = Glow(diameter: 176, blur: 40)
        /// The hat while words are drawn into it.
        public static let wordDraw = Glow(diameter: 168, blur: 36)
        /// The hat while it is shuffled, kept tighter over the dimmed screen.
        public static let shuffle = Glow(diameter: 168, blur: 30)
        /// The filled hat before a game starts.
        public static let filledHat = Glow(diameter: 150, blur: 34)
        /// The winner's trophy.
        public static let trophy = Glow(diameter: 140, blur: 32)
        /// A waiting or connecting status hero.
        public static let status = Glow(diameter: 120, blur: 28)
        /// A team's turn results.
        public static let team = Glow(diameter: 104, blur: 16)
        /// A setup screen's compact hero.
        public static let setup = Glow(diameter: 96, blur: 22)
    }
}
