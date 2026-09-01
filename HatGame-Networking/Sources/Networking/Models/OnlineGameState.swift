//
//  OnlineGameState.swift
//  Networking
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
}

public enum OnlineGameRound: Int, Codable, CaseIterable, Sendable {
    case first = 1
    case second = 2
    case third = 3

    public var next: OnlineGameRound? {
        switch self {
        case .first: .second
        case .second: .third
        case .third: nil
        }
    }
}

public struct OnlineGameState: Codable, Sendable {
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

    public init(
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
        isSkippingEnabled: Bool = true
    ) {
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

    // MARK: - Codable
    /// Firebase strips empty arrays/dicts and rewrites scores with
    /// non-string keys. Custom decoder defaults each collection to empty.
    private enum CodingKeys: String, CodingKey {
        case currentRound, currentTeamIndex, teamExplainerIndices, currentWordId,
             remainingWordIds, allWordIds, scores, phase, activePlayerId,
             timerStartedAt, roundDuration, isSkippingEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currentRound = try container.decode(OnlineGameRound.self, forKey: .currentRound)
        self.currentTeamIndex = try container.decode(Int.self, forKey: .currentTeamIndex)
        self.teamExplainerIndices = (try? container.decode([String: Int].self, forKey: .teamExplainerIndices)) ?? [:]
        self.currentWordId = try container.decodeIfPresent(String.self, forKey: .currentWordId)
        self.remainingWordIds = (try? container.decode([String].self, forKey: .remainingWordIds)) ?? []
        self.allWordIds = (try? container.decode([String].self, forKey: .allWordIds)) ?? []
        self.scores = (try? container.decode([String: [OnlineGameRound: Int]].self, forKey: .scores)) ?? [:]
        self.phase = try container.decode(GamePhase.self, forKey: .phase)
        self.activePlayerId = try container.decodeIfPresent(String.self, forKey: .activePlayerId)
        self.timerStartedAt = try container.decodeIfPresent(Date.self, forKey: .timerStartedAt)
        self.roundDuration = try container.decode(Int.self, forKey: .roundDuration)
        self.isSkippingEnabled = (try? container.decode(Bool.self, forKey: .isSkippingEnabled)) ?? true
    }
}
