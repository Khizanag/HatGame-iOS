//
//  DesignBook+Shadow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import SwiftUI

extension DesignBook {
    public enum Shadow {
        case small
        case medium
        case large
        case accent
        case none

        fileprivate var style: ShadowStyle {
            switch self {
            case .small:
                ShadowStyle(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            case .medium:
                ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            case .large:
                ShadowStyle(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
            case .accent:
                ShadowStyle(
                    color: SwiftUI.Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            case .none:
                ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
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
