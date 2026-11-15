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

        // MARK: - Eases
        public static let quick = SwiftUI.Animation.easeInOut(duration: 0.18)
        public static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)

        /// Returns the given animation, or `nil` when Reduce Motion is enabled.
        public static func respectingReducedMotion(
            _ animation: SwiftUI.Animation,
            reduceMotion: Bool
        ) -> SwiftUI.Animation? {
            reduceMotion ? nil : animation
        }
    }
}
