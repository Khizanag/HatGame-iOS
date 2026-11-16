//
//  OnlineGameRound+Title.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Networking

// MARK: - Localized round copy
extension OnlineGameRound {
    /// A round this build cannot read shows as the last round.
    var title: String {
        switch self {
        case .first: localized("round.first.title")
        case .second: localized("round.second.title")
        case .third, .unsupported: localized("round.third.title")
        }
    }

    var description: String {
        switch self {
        case .first: localized("round.first.description")
        case .second: localized("round.second.description")
        case .third, .unsupported: localized("round.third.description")
        }
    }
}
