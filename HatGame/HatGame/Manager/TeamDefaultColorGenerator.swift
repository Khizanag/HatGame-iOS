//
//  TeamDefaultColorGenerator.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.25.
//

import SwiftUI

struct TeamDefaultColorGenerator {
    nonisolated static let defaultColors: [Color] = [
        Color(red: 0.3, green: 0.6, blue: 1.0),
        Color(red: 1.0, green: 0.4, blue: 0.4),
        Color(red: 0.4, green: 0.8, blue: 0.4),
        Color(red: 1.0, green: 0.7, blue: 0.2),
        Color(red: 0.8, green: 0.3, blue: 0.8),
        Color(red: 0.2, green: 0.8, blue: 0.8),
        Color(red: 1.0, green: 0.5, blue: 0.7),
        Color(red: 0.6, green: 0.4, blue: 0.9),
        Color(red: 0.9, green: 0.9, blue: 0.3),
        Color(red: 0.5, green: 0.3, blue: 0.2),
    ]

    /// The first palette color no team in `configuration` uses yet, or the
    /// first palette color when all are taken.
    func generateDefaultColor(for configuration: GameConfiguration) -> Color {
        let occupiedColors = configuration.teams.map(\.color)
        return Self.defaultColors.first { !isColorOccupied($0, in: occupiedColors) } ?? Self.defaultColors[0]
    }

    private func isColorOccupied(_ color: Color, in occupiedColors: [Color]) -> Bool {
        occupiedColors.contains { occupiedColor in
            areColorsEqual(color, occupiedColor)
        }
    }

    private func areColorsEqual(_ color1: Color, _ color2: Color) -> Bool {
        color1.isApproximatelyEqual(to: color2)
    }
}
