//
//  Word.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Foundation

nonisolated struct Word: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let text: String
    /// The player who put the word in the hat; `nil` for generated words.
    let authorId: UUID?

    init(
        id: UUID = UUID(),
        text: String,
        authorId: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.authorId = authorId
    }
}
