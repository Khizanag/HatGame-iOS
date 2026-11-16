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

    /// A player's own submission. Ids derive from the player and position,
    /// so resending after a timed-out write overwrites the same entries
    /// instead of adding the words to the hat a second time.
    public static func submission(_ texts: [String], by playerId: String) -> [OnlineWord] {
        texts.enumerated().map { index, text in
            OnlineWord(id: "\(playerId)-\(index)", text: text, addedByPlayerId: playerId)
        }
    }
}
