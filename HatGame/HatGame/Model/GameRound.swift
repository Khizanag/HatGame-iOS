//
//  GameRound.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.25.
//

import SwiftUI

enum GameRound: Int, Codable, CaseIterable, Equatable, Hashable {
    case first = 1
    case second = 2
    case third = 3

    var description: String {
        switch self {
        case .first:
            localized("gameRound.first.description")
        case .second:
            localized("gameRound.second.description")
        case .third:
            localized("gameRound.third.description")
        }
    }

    var title: String {
        String(format: localized("gameRound.title"), rawValue)
    }

    /// SF Symbol that hints at the round's flavor — describe / hint / mime.
    var symbol: String {
        switch self {
        case .first: "bubble.left.and.bubble.right.fill"
        case .second: "lightbulb.fill"
        case .third: "hand.raised.fingers.spread.fill"
        }
    }
}
