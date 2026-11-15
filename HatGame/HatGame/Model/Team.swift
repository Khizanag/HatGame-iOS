//
//  Team.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import SwiftUI

nonisolated struct Team: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var players: [Player]
    let teamColor: TeamColor

    var color: Color { teamColor.color }

    init(
        id: UUID = UUID(),
        name: String,
        players: [Player] = [],
        teamColor: TeamColor
    ) {
        self.id = id
        self.name = name
        self.players = players
        self.teamColor = teamColor
    }

    init(
        id: UUID = UUID(),
        name: String,
        players: [Player] = [],
        color: Color
    ) {
        self.init(id: id, name: name, players: players, teamColor: TeamColor(color))
    }
}
