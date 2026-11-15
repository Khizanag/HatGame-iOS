//
//  RoomWrites.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// Boolean leaves on a player node that are written on their own, so a flag
/// change never rewrites — and clobbers — the rest of the player.
public enum PlayerFlag: String, Sendable {
    case hasSubmittedWords
    case isConnected
}

/// Every lobby write as a multi-path update relative to `rooms/<id>`: keys
/// are child paths, values are what Realtime Database stores there (`NSNull`
/// deletes). `FirebaseService` sends exactly these, and the rules check
/// replays them, so the two can never drift apart.
public enum RoomWrites {
    public typealias Updates = [String: Any]

    /// Adds a player node. A whole-node write: an earlier attempt that landed
    /// is replaced by the identical value.
    public static func addPlayer(_ player: OnlinePlayer) throws -> Updates {
        ["players/\(player.id)": try FirebaseCoding.dictionary(from: player)]
    }

    public static func playerFlag(_ flag: PlayerFlag, to value: Bool, playerId: String) -> Updates {
        ["players/\(playerId)/\(flag.rawValue)": value]
    }

    public static func addTeam(_ team: OnlineTeam) throws -> Updates {
        ["teams/\(team.id)": try FirebaseCoding.dictionary(from: team)]
    }

    /// Deletes the team and clears every member's `teamId` in one update, so
    /// no player is left pointing at a missing team.
    public static func removeTeam(_ teamId: String, unassigning memberIds: [String]) -> Updates {
        var updates: Updates = ["teams/\(teamId)": NSNull()]
        for memberId in memberIds {
            updates["players/\(memberId)/teamId"] = NSNull()
        }
        return updates
    }

    /// Moves a player between teams — or off every team when `newTeamId` is
    /// nil — updating both sides of the relationship together.
    public static func reassign(
        playerId: String,
        previousTeamId: String?,
        newTeamId: String?,
        teams: [OnlineTeam]
    ) -> Updates {
        var updates: Updates = ["players/\(playerId)/teamId": newTeamId as Any? ?? NSNull()]
        if let previousTeamId, let previous = teams.first(where: { $0.id == previousTeamId }) {
            updates["teams/\(previousTeamId)/playerIds"] = previous.playerIds.filter { $0 != playerId }
        }
        if let newTeamId, let next = teams.first(where: { $0.id == newTeamId }) {
            updates["teams/\(newTeamId)/playerIds"] = next.playerIds.filter { $0 != playerId } + [playerId]
        }
        return updates
    }

    /// Adds `words` and opens each listed player's submission gate in the
    /// same update — all-or-nothing, touching only the flag leaf.
    public static func fillWords(_ words: [OnlineWord], markSubmitted playerIds: [String]) throws -> Updates {
        var updates: Updates = [:]
        for word in words {
            updates["words/\(word.id)"] = try FirebaseCoding.dictionary(from: word)
        }
        for playerId in playerIds {
            updates["players/\(playerId)/hasSubmittedWords"] = true
        }
        return updates
    }

    public static func status(_ status: RoomStatus) -> Updates {
        ["status": status.rawValue]
    }
}
