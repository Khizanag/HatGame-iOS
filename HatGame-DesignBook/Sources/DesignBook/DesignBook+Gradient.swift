//
//  DesignBook+Gradient.swift
//  DesignBook Package
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import SwiftUI

extension DesignBook {
    public enum Gradient {
        /// Soft brand gradient — used behind the home hero and on the game card.
        public static let brandBackdrop = LinearGradient(
            colors: [
                SwiftUI.Color(red: 0.42, green: 0.55, blue: 1.00).opacity(0.18),
                SwiftUI.Color(red: 0.78, green: 0.38, blue: 0.95).opacity(0.10),
                SwiftUI.Color.clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Vivid gradient used on primary CTAs and active states.
        public static let primary = LinearGradient(
            colors: [
                SwiftUI.Color(red: 0.36, green: 0.50, blue: 1.00),
                SwiftUI.Color(red: 0.68, green: 0.34, blue: 0.96),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Warm gradient for celebratory winner moments.
        public static let celebration = LinearGradient(
            colors: [
                SwiftUI.Color(red: 1.00, green: 0.78, blue: 0.27),
                SwiftUI.Color(red: 1.00, green: 0.45, blue: 0.40),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Urgency gradient used when the timer is running low.
        public static let urgency = LinearGradient(
            colors: [
                SwiftUI.Color(red: 1.00, green: 0.36, blue: 0.36),
                SwiftUI.Color(red: 1.00, green: 0.55, blue: 0.20),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Builds a gradient stroke tinted to a team color.
        public static func team(_ tint: SwiftUI.Color) -> LinearGradient {
            LinearGradient(
                colors: [
                    tint.opacity(0.85),
                    tint.opacity(0.55),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
