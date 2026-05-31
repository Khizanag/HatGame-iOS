//
//  GameRoom.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Foundation

public enum RoomStatus: String, Codable, Sendable {
    case waiting
    case setup
    case playing
    case finished
}

public struct GameRoom: Codable, Identifiable, Sendable {
    public let id: String
    public let hostId: String
    public var status: RoomStatus
    public var settings: GameSettings
    public var teams: [OnlineTeam]
    public var players: [OnlinePlayer]
    public var gameState: OnlineGameState?
    public let createdAt: Date

    public init(
        id: String,
        hostId: String,
        status: RoomStatus = .waiting,
        settings: GameSettings = GameSettings(),
        teams: [OnlineTeam] = [],
        players: [OnlinePlayer] = [],
        gameState: OnlineGameState? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hostId = hostId
        self.status = status
        self.settings = settings
        self.teams = teams
        self.players = players
        self.gameState = gameState
        self.createdAt = createdAt
    }

    // MARK: - Codable
    /// Firebase RTDB drops empty collections from the stored snapshot and
    /// rewrites collections that were stored under child paths as
    /// dictionaries keyed by their child ID. Custom decoder handles both.
    private enum CodingKeys: String, CodingKey {
        case id, hostId, status, settings, teams, players, gameState, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.hostId = try container.decode(String.self, forKey: .hostId)
        self.status = try container.decode(RoomStatus.self, forKey: .status)
        self.settings = try container.decode(GameSettings.self, forKey: .settings)
        self.teams = try container.decodeFirebaseCollection([OnlineTeam].self, forKey: .teams)
        self.players = try container.decodeFirebaseCollection([OnlinePlayer].self, forKey: .players)
        self.gameState = try container.decodeIfPresent(OnlineGameState.self, forKey: .gameState)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

public struct GameSettings: Codable, Sendable {
    public var maxTeams: Int
    public var playersPerTeam: Int
    public var wordsPerPlayer: Int
    public var roundDuration: Int
    public var isSkippingEnabled: Bool
    public var isAutomaticWords: Bool

    public init(
        maxTeams: Int = 4,
        playersPerTeam: Int = 2,
        wordsPerPlayer: Int = 5,
        roundDuration: Int = 60,
        isSkippingEnabled: Bool = true,
        isAutomaticWords: Bool = false
    ) {
        self.maxTeams = maxTeams
        self.playersPerTeam = playersPerTeam
        self.wordsPerPlayer = wordsPerPlayer
        self.roundDuration = roundDuration
        self.isSkippingEnabled = isSkippingEnabled
        self.isAutomaticWords = isAutomaticWords
    }

    // MARK: - Codable
    /// Firebase RTDB strips defaulted values, and rooms created before these
    /// flags existed omit them entirely — decode each defensively so older
    /// in-flight rooms keep decoding with today's behavior as the default.
    private enum CodingKeys: String, CodingKey {
        case maxTeams, playersPerTeam, wordsPerPlayer, roundDuration,
             isSkippingEnabled, isAutomaticWords
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.maxTeams = try container.decodeIfPresent(Int.self, forKey: .maxTeams) ?? 4
        self.playersPerTeam = try container.decodeIfPresent(Int.self, forKey: .playersPerTeam) ?? 2
        self.wordsPerPlayer = try container.decodeIfPresent(Int.self, forKey: .wordsPerPlayer) ?? 5
        self.roundDuration = try container.decodeIfPresent(Int.self, forKey: .roundDuration) ?? 60
        self.isSkippingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSkippingEnabled) ?? true
        self.isAutomaticWords = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticWords) ?? false
    }
}
