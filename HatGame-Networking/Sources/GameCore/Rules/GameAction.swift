//
//  GameAction.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// A request to move an in-progress game forward. Both transports funnel
/// every gameplay mutation through `OnlineGameRules.apply`, so the same action
/// produces the same state whether it runs inside a Firebase transaction or
/// on the Multipeer host.
public enum GameAction: Codable, Sendable, Equatable {
    case startTurn
    /// Carries the word the explainer saw so a duplicate or late tap — the
    /// word has already moved on — is rejected instead of scoring twice.
    case markGuessed(wordId: String)
    case skip(wordId: String)
    case endTurn
    case advanceAfterTurnResults
    case advanceAfterRoundResults
}

/// A request to change the lobby or word pool before the game starts.
public enum RoomAction: Codable, Sendable, Equatable {
    case joinTeam(teamId: String)
    case leaveTeam
    case createTeam(name: String, colorHex: String)
    case removeTeam(teamId: String)
    case startGame
    case submitWords([String])
}

/// Everything outside `OnlineGameState` that a transition reads.
public struct GameContext: Sendable {
    public let hostId: String
    public let teams: [OnlineTeam]
    public let players: [OnlinePlayer]
    public let now: Date

    public init(hostId: String, teams: [OnlineTeam], players: [OnlinePlayer], now: Date) {
        self.hostId = hostId
        self.teams = teams
        self.players = players
        self.now = now
    }

    public init(room: GameRoom, now: Date = Date()) {
        self.init(hostId: room.hostId, teams: room.teams, players: room.players, now: now)
    }
}
