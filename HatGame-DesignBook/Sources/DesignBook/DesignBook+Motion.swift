//
//  DesignBook+Motion.swift
//  DesignBook Package
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import SwiftUI

extension DesignBook {
    public enum Motion {
        // MARK: - Springs
        /// Crisp, snappy spring for primary interactions (taps, selections)
        public static let snappy = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.78)
        /// Soft, fluid spring for content transitions
        public static let smooth = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.85)
        /// Playful bouncy spring for celebratory moments
        public static let bouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.62)
        /// The spring a drawn result lands with, such as the starting team.
        public static let reveal = SwiftUI.Animation.spring(response: 0.55, dampingFraction: 0.72)
        /// The bounce back after a quick swell, such as the hat taking a word.
        public static let rebound = SwiftUI.Animation.spring(duration: 0.3, bounce: 0.45)

        // MARK: - Eases
        public static let quick = SwiftUI.Animation.easeInOut(duration: 0.18)
        public static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        /// One step of a roulette highlight moving to the next row.
        public static let step = SwiftUI.Animation.snappy(duration: 0.14)
        /// One flicker of a random pick before it settles.
        public static let flicker = SwiftUI.Animation.easeInOut(duration: 0.1)
        /// An instant swell or flare.
        public static let flash = SwiftUI.Animation.easeOut(duration: 0.07)
        /// A flare fading back after `flash`.
        public static let fadeBack = SwiftUI.Animation.easeIn(duration: 0.35)
        /// A drawn word sharpening out of its blur.
        public static let sharpen = SwiftUI.Animation.easeOut(duration: 0.34)
        /// One step of a progress bar filling as words are drawn.
        public static let drawProgress = SwiftUI.Animation.linear(duration: 0.16)
        /// The countdown ring sweeping one second.
        public static let countdownTick = SwiftUI.Animation.linear(duration: 1)

        // MARK: - Loops
        /// A hero glyph's slow loop, floating or pulsing.
        public static let heroLoop = SwiftUI.Animation
            .easeInOut(duration: 2.4)
            .repeatForever(autoreverses: true)
        /// The hat bobbing while words are drawn into it.
        public static let hatBob = SwiftUI.Animation
            .easeInOut(duration: 1.6)
            .repeatForever(autoreverses: true)
        /// The timer throbbing in its last seconds.
        public static let urgentPulse = SwiftUI.Animation
            .easeInOut(duration: 0.45)
            .repeatForever(autoreverses: true)

        // MARK: - Durations
        /// Seconds a score takes to count up to its value.
        public static let scoreCount: Double = 0.9
        /// A turn's points or a running total counting up.
        public static let scoreCountMedium: Double = 0.7
        /// A row of a standings table counting up.
        public static let scoreCountShort: Double = 0.6
        /// Seconds the shuffle runs the first time in a session.
        public static let fullShuffle: Double = 2.6
        /// Seconds the shuffle runs after the first time, or under Reduce Motion.
        public static let shortShuffle: Double = 0.8
        /// Seconds after the shuffle for the last slip to go in.
        public static let shuffleSettle: Double = 0.2

        // MARK: - Choreography
        /// The pause before a results screen celebrates.
        public static let celebrationDelay: Duration = .milliseconds(180)
        /// The pause before a turn's results celebrate.
        public static let turnCelebrationDelay: Duration = .milliseconds(120)
        /// Between two words drawn from the pool.
        public static let drawInterval: Duration = .milliseconds(160)
        /// Between two words drawn from the pool under Reduce Motion.
        public static let reducedDrawInterval: Duration = .milliseconds(340)
        /// Between two flickers of a random pick.
        public static let flickerInterval: Duration = .milliseconds(100)
        /// How long a random pick holds before it settles.
        public static let pickHold: Duration = .milliseconds(300)
        /// How long the roulette holds on the winner before it is revealed.
        public static let rouletteHold: Duration = .milliseconds(380)
        /// Before the first auto-filled word is typed in.
        public static let autoFillLead: Duration = .milliseconds(500)
        /// Between two auto-filled words.
        public static let autoFillInterval: Duration = .milliseconds(300)
        /// How long a "Copied" confirmation stays before reverting.
        public static let confirmationHold: Duration = .seconds(2)

        /// Returns the given animation, or `nil` when Reduce Motion is enabled.
        public static func respectingReducedMotion(
            _ animation: SwiftUI.Animation,
            reduceMotion: Bool
        ) -> SwiftUI.Animation? {
            reduceMotion ? nil : animation
        }
    }
}
