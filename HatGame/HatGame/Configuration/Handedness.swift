//
//  Handedness.swift
//  HatGame
//
//  Created by Giga Khizanishvili
//

import Foundation

enum Handedness: String, CaseIterable {
    case left
    case right

    var displayName: String {
        switch self {
        case .left:
            localized("settings.handedness.left")
        case .right:
            localized("settings.handedness.right")
        }
    }

    var systemImage: String {
        switch self {
        case .left:
            "hand.point.left.fill"
        case .right:
            "hand.point.right.fill"
        }
    }
}
