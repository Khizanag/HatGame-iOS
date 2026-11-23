//
//  DesignBook+Shadow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import SwiftUI

extension DesignBook {
    public enum Shadow {
        case none
        /// A badge lifted just off what it is pinned to.
        case small
        case medium
        case large
        case accent
        /// A hero card lifted off the screen in its team's tint.
        case lifted(SwiftUI.Color)
        /// The warm glow under a winner's trophy.
        case celebration
        /// A softer `celebration`, for a trophy inside a card.
        case softCelebration
        /// A halo in `color` around a selected row; none when unselected,
        /// so the halo fades in and out rather than growing.
        case selectionGlow(SwiftUI.Color, isSelected: Bool)
        /// The halo around the countdown ring, flaring in the last seconds.
        case timerGlow(SwiftUI.Color, isUrgent: Bool)

        fileprivate var style: ShadowStyle {
            switch self {
            case .none:
                ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
            case .small:
                ShadowStyle(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            case .medium:
                ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            case .large:
                ShadowStyle(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
            case .accent:
                ShadowStyle(
                    color: DesignBook.Color.Text.accent.opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            case .lifted(let tint):
                ShadowStyle(color: tint.opacity(0.2), radius: 28, x: 0, y: 14)
            case .celebration:
                ShadowStyle(color: DesignBook.Color.celebrationGlow.opacity(0.55), radius: 22, x: 0, y: 10)
            case .softCelebration:
                ShadowStyle(color: DesignBook.Color.celebrationGlow.opacity(0.4), radius: 18, x: 0, y: 8)
            case let .selectionGlow(color, isSelected):
                ShadowStyle(color: color.opacity(isSelected ? 0.45 : 0), radius: 14, x: 0, y: 0)
            case let .timerGlow(color, isUrgent):
                ShadowStyle(
                    color: color.opacity(isUrgent ? 0.5 : 0.15),
                    radius: isUrgent ? 12 : 6,
                    x: 0,
                    y: 0
                )
            }
        }

        fileprivate struct ShadowStyle {
            let color: SwiftUI.Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }
}

// MARK: - Shadow modifier
extension View {
    public func shadow(_ shadow: DesignBook.Shadow) -> some View {
        self.shadow(
            color: shadow.style.color,
            radius: shadow.style.radius,
            x: shadow.style.x,
            y: shadow.style.y
        )
    }
}
