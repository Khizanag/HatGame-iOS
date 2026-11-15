//
//  Player.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Foundation

nonisolated struct Player: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let name: String
    let teamId: UUID

    init(id: UUID = UUID(), name: String, teamId: UUID) {
        self.id = id
        self.name = name
        self.teamId = teamId
    }
}
