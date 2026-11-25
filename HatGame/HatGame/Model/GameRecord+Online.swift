//
//  GameRecord+Online.swift
//  HatGame
//

import Foundation
import Networking

// MARK: - Building from a multiplayer room
extension GameRecord {
    /// The record of a finished online or nearby game, or `nil` while the
    /// room has no game. Multiplayer keeps scores only, not turns.
    init?(room: GameRoom, mode: Mode, endedAt: Date = .now) {
        guard let state = room.gameState else { return nil }
        let teams = room.teams.map { team in
            TeamResult(
                id: team.id,
                name: team.name,
                color: TeamColor(team.color),
                players: team.playerIds.compactMap { id in room.players.first { $0.id == id }?.name },
                roundScores: OnlineGameRound.allCases.map { state.getScore(for: team.id, in: $0) }
            )
        }
        let scoreKey = teams.map { "\($0.id):\($0.total)" }.joined(separator: ",")
        self.init(
            id: UUID(),
            mode: mode,
            outcome: .finished,
            startedAt: nil,
            endedAt: endedAt,
            roundsPlayed: OnlineGameRound.allCases.count,
            settings: Settings(
                roundDuration: state.roundDuration,
                wordCount: state.allWordIds.count,
                isSkippingEnabled: state.isSkippingEnabled,
                skipPenalty: state.skipPenalty
            ),
            teams: teams,
            turns: [],
            sourceKey: "\(mode.rawValue)-\(room.id)-\(scoreKey)"
        )
    }
}
