//
//  OnlineGameState.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Foundation

public enum GamePhase: String, Codable, Sendable {
    case teamPrep
    case playing
    case turnResults
    case roundResults
    case finished
    /// A phase written by a newer build; see `RoomStatus.unsupported`.
    case unsupported

    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = GamePhase(rawValue: rawValue) ?? .unsupported
    }
}

public enum OnlineGameRound: Int, Codable, CaseIterable, Sendable {
    /// A round written by a newer build; see `RoomStatus.unsupported`.
    case unsupported = 0
    case first = 1
    case second = 2
    case third = 3

    /// The playable rounds, in order. `unsupported` is deliberately absent.
    public static let allCases: [OnlineGameRound] = [.first, .second, .third]

    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(Int.self)
        self = OnlineGameRound(rawValue: rawValue) ?? .unsupported
    }

    public var next: OnlineGameRound? {
        switch self {
        case .first: .second
        case .second: .third
        case .third, .unsupported: nil
        }
    }
}

public struct OnlineGameState: VersionedNode {
    /// The wire generation that wrote this state; see `WireSchema`.
    public var schemaVersion: Int
    public var currentRound: OnlineGameRound
    public var currentTeamIndex: Int
    /// Per-team explainer index. Each team rotates its own explainer
    /// independently of other teams.
    public var teamExplainerIndices: [String: Int]
    public var currentWordId: String?
    public var remainingWordIds: [String]
    public var allWordIds: [String]
    public var scores: [String: [OnlineGameRound: Int]]
    public var phase: GamePhase
    public var activePlayerId: String?
    public var timerStartedAt: Date?
    public var roundDuration: Int
    /// Frozen at game start from the host's `GameSettings` — authoritative for
    /// every peer so all clients agree on whether skipping is allowed.
    public var isSkippingEnabled: Bool
    /// Points a team loses per skipped word, frozen at game start like
    /// `isSkippingEnabled`. Already taken off `scores` as each skip lands.
    public var skipPenalty: Int
    /// Seconds a team keeps for its next turn after emptying the hat with
    /// time left (see `docs/rounds.md`). Consumed when that turn starts.
    public var carryOverSeconds: [String: Int]
    /// Length of the running turn — a full `roundDuration` or a carried-over
    /// remainder. `nil` between turns.
    public var turnSeconds: Int?

    public init(
        schemaVersion: Int = WireSchema.currentVersion,
        currentRound: OnlineGameRound = .first,
        currentTeamIndex: Int = 0,
        teamExplainerIndices: [String: Int] = [:],
        currentWordId: String? = nil,
        remainingWordIds: [String] = [],
        allWordIds: [String] = [],
        scores: [String: [OnlineGameRound: Int]] = [:],
        phase: GamePhase = .teamPrep,
        activePlayerId: String? = nil,
        timerStartedAt: Date? = nil,
        roundDuration: Int = 60,
        isSkippingEnabled: Bool = true,
        skipPenalty: Int = 0,
        carryOverSeconds: [String: Int] = [:],
        turnSeconds: Int? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.currentRound = currentRound
        self.currentTeamIndex = currentTeamIndex
        self.teamExplainerIndices = teamExplainerIndices
        self.currentWordId = currentWordId
        self.remainingWordIds = remainingWordIds
        self.allWordIds = allWordIds
        self.scores = scores
        self.phase = phase
        self.activePlayerId = activePlayerId
        self.timerStartedAt = timerStartedAt
        self.roundDuration = roundDuration
        self.isSkippingEnabled = isSkippingEnabled
        self.skipPenalty = skipPenalty
        self.carryOverSeconds = carryOverSeconds
        self.turnSeconds = turnSeconds
    }

    public func getScore(for teamId: String, in round: OnlineGameRound) -> Int {
        scores[teamId]?[round] ?? 0
    }

    public func getTotalScore(for teamId: String) -> Int {
        scores[teamId]?.values.reduce(0, +) ?? 0
    }

    public func explainerIndex(for teamId: String) -> Int {
        teamExplainerIndices[teamId] ?? 0
    }

    /// False when a newer build wrote this state: its schema, phase, or
    /// round is beyond what this build understands.
    public var isSupported: Bool {
        WireSchema.isSupported(schemaVersion) && phase != .unsupported && currentRound != .unsupported
    }

    // MARK: - Codable
    /// Firebase strips empty arrays/dicts, so a missing collection decodes as
    /// empty. A present-but-malformed value throws rather than silently
    /// resetting — a reset would wipe every team's score.
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, currentRound, currentTeamIndex, teamExplainerIndices, currentWordId,
             remainingWordIds, allWordIds, scores, phase, activePlayerId,
             timerStartedAt, roundDuration, isSkippingEnabled, skipPenalty, carryOverSeconds, turnSeconds
    }

    public static var knownKeys: Set<String> {
        Set(CodingKeys.allCases.map(\.stringValue))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // States written before versioning are the first generation.
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.currentRound = try container.decode(OnlineGameRound.self, forKey: .currentRound)
        self.currentTeamIndex = try container.decode(Int.self, forKey: .currentTeamIndex)
        self.teamExplainerIndices = try container.decodeIfPresent(
            [String: Int].self,
            forKey: .teamExplainerIndices
        ) ?? [:]
        self.currentWordId = try container.decodeIfPresent(String.self, forKey: .currentWordId)
        self.remainingWordIds = try container.decodeIfPresent([String].self, forKey: .remainingWordIds) ?? []
        self.allWordIds = try container.decodeIfPresent([String].self, forKey: .allWordIds) ?? []
        self.scores = try container.decodeIfPresent([String: [OnlineGameRound: Int]].self, forKey: .scores) ?? [:]
        self.phase = try container.decode(GamePhase.self, forKey: .phase)
        self.activePlayerId = try container.decodeIfPresent(String.self, forKey: .activePlayerId)
        self.timerStartedAt = try container.decodeIfPresent(Date.self, forKey: .timerStartedAt)
        self.roundDuration = try container.decode(Int.self, forKey: .roundDuration)
        self.isSkippingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSkippingEnabled) ?? true
        self.skipPenalty = try container.decodeIfPresent(Int.self, forKey: .skipPenalty) ?? 0
        self.carryOverSeconds = try container.decodeIfPresent([String: Int].self, forKey: .carryOverSeconds) ?? [:]
        self.turnSeconds = try container.decodeIfPresent(Int.self, forKey: .turnSeconds)
    }
}
