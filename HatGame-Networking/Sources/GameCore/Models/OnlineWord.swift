//
//  OnlineWord.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Foundation

public struct OnlineWord: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let text: String
    public let addedByPlayerId: String

    public init(
        id: String = UUID().uuidString,
        text: String,
        addedByPlayerId: String
    ) {
        self.id = id
        self.text = RoomLimits.word(text)
        self.addedByPlayerId = addedByPlayerId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: OnlineWord, rhs: OnlineWord) -> Bool {
        lhs.id == rhs.id
    }
}
