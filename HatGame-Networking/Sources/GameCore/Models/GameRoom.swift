//
//  GameRoom.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Foundation

public enum RoomStatus: String, Codable, Sendable {
    case waiting
    case setup
    case playing
    case finished
    /// A status written by a newer build. Decoding never fails on it, so an
    /// older client can show "update the app" instead of losing the room.
    case unsupported

    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = RoomStatus(rawValue: rawValue) ?? .unsupported
    }

    public var isLobby: Bool {
        self == .waiting || self == .setup
    }
}

public struct GameRoom: Codable, Identifiable, Sendable {
    public let id: String
    public let hostId: String
    /// The wire generation that created this room; see `WireSchema`.
    public let schemaVersion: Int
    public var status: RoomStatus
    public var settings: GameSettings
    public var teams: [OnlineTeam]
    public var players: [OnlinePlayer]
    public var gameState: OnlineGameState?
    public let createdAt: Date

    public init(
        id: String,
        hostId: String,
        schemaVersion: Int = WireSchema.currentVersion,
        status: RoomStatus = .waiting,
        settings: GameSettings = GameSettings(),
        teams: [OnlineTeam] = [],
        players: [OnlinePlayer] = [],
        gameState: OnlineGameState? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hostId = hostId
        self.schemaVersion = schemaVersion
        self.status = status
        self.settings = settings
        self.teams = Self.canonicalOrder(teams)
        self.players = Self.canonicalOrder(players)
        self.gameState = gameState
        self.createdAt = createdAt
    }

    /// The same room with `teams` and `players` in canonical order. Every
    /// mutation that appends or removes elements returns through here so the
    /// Multipeer host's in-memory order matches what its guests decode —
    /// `OnlineGameState.currentTeamIndex` indexes into `teams`.
    public func canonicallyOrdered() -> GameRoom {
        var copy = self
        copy.teams = Self.canonicalOrder(teams)
        copy.players = Self.canonicalOrder(players)
        return copy
    }

    /// False when a newer build wrote a schema, status, phase, or round this
    /// build cannot interpret.
    public var isSupported: Bool {
        WireSchema.isSupported(schemaVersion) && status != .unsupported && gameState?.isSupported != false
    }

    // MARK: - Codable
    /// Firebase RTDB drops empty collections from the stored snapshot and
    /// rewrites collections that were stored under child paths as
    /// dictionaries keyed by their child ID. Custom decoder handles both.
    private enum CodingKeys: String, CodingKey {
        case id, hostId, schemaVersion, status, settings, teams, players, gameState, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.hostId = try container.decode(String.self, forKey: .hostId)
        // Rooms written before versioning are the first generation.
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.status = try container.decode(RoomStatus.self, forKey: .status)
        self.settings = try container.decode(GameSettings.self, forKey: .settings)
        self.teams = Self.canonicalOrder(try container.decodeFirebaseCollection([OnlineTeam].self, forKey: .teams))
        self.players = Self.canonicalOrder(
            try container.decodeFirebaseCollection([PlayerRecord].self, forKey: .players).compactMap(\.player)
        )
        self.gameState = try container.decodeIfPresent(OnlineGameState.self, forKey: .gameState)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    /// Writes `players` and `teams` keyed by their own id. Every later write
    /// addresses `players/<id>` and `teams/<id>`, so an array here would make
    /// Realtime Database store the first element at `/0` and grow a second,
    /// partial node for the same entity on the first child update.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(hostId, forKey: .hostId)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(status, forKey: .status)
        try container.encode(settings, forKey: .settings)
        try container.encode(Self.keyedById(teams), forKey: .teams)
        try container.encode(Self.keyedById(players), forKey: .players)
        try container.encodeIfPresent(gameState, forKey: .gameState)
        try container.encode(createdAt, forKey: .createdAt)
    }

    private static func canonicalOrder(_ teams: [OnlineTeam]) -> [OnlineTeam] {
        teams.sorted { lhs, rhs in
            let lhsDate = lhs.createdAt ?? .distantPast
            let rhsDate = rhs.createdAt ?? .distantPast
            return lhsDate == rhsDate ? lhs.id < rhs.id : lhsDate < rhsDate
        }
    }

    private static func canonicalOrder(_ players: [OnlinePlayer]) -> [OnlinePlayer] {
        players.sorted { lhs, rhs in
            lhs.joinedAt == rhs.joinedAt ? lhs.id < rhs.id : lhs.joinedAt < rhs.joinedAt
        }
    }

    private static func keyedById<Element: Identifiable>(_ elements: [Element]) -> [String: Element]
    where Element.ID == String {
        Dictionary(elements.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }
}

/// A `players/<id>` entry. A presence write that lands after its player was
/// removed leaves a node holding only `isConnected`; it carries no `id` and
/// is skipped rather than failing the whole room. Any entry that has an `id`
/// must decode fully.
private struct PlayerRecord: Decodable {
    let player: OnlinePlayer?

    private enum ProbeKeys: String, CodingKey {
        case id
    }

    init(from decoder: Decoder) throws {
        let probe = try decoder.container(keyedBy: ProbeKeys.self)
        player = probe.contains(.id) ? try OnlinePlayer(from: decoder) : nil
    }
}

public struct GameSettings: Codable, Equatable, Sendable {
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
