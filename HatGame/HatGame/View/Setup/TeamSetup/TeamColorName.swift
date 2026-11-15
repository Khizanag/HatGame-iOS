//
//  TeamColorName.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// Spoken names for the team color palette, in
/// `TeamDefaultColorGenerator.defaultColors` order.
enum TeamColorName {
    private static let keys: [String.LocalizationValue] = [
        "teamForm.color.name.blue",
        "teamForm.color.name.red",
        "teamForm.color.name.green",
        "teamForm.color.name.orange",
        "teamForm.color.name.purple",
        "teamForm.color.name.teal",
        "teamForm.color.name.pink",
        "teamForm.color.name.violet",
        "teamForm.color.name.yellow",
        "teamForm.color.name.brown",
    ]

    /// The localized name of the palette color at `index`, or a generic
    /// "Team color" when the palette outgrows this list.
    static func name(forPaletteIndex index: Int) -> String {
        localized(keys[safe: index] ?? "teamForm.color.swatch.unselected")
    }
}
