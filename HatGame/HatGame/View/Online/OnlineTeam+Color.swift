//
//  OnlineTeam+Color.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import Networking
import SwiftUI

// MARK: - Team color
extension OnlineTeam {
    /// The team's chosen color, or the accent when its stored hex is unreadable.
    var color: Color {
        Color(hex: colorHex) ?? TeamDefaultColorGenerator.defaultColors[0]
    }
}
