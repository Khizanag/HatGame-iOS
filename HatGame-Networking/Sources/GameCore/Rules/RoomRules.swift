//
//  RoomRules.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// Pure lobby and word-pool mutations. Each returns `nil` when its
/// precondition fails; results come back in canonical order so every peer
/// indexes the same team at the same position.
public enum RoomRules {
    public static let minimumTeams = 2
    public static let minimumPlayersPerTeam = 2

    // MARK: - Authority
    /// Team management and starting the game belong to the host; any player
    /// in the room may manage their own membership and words.
    public static func canPerform(_ action: RoomAction, by playerId: String, in room: GameRoom) -> Bool {
        switch action {
        case .createTeam, .removeTeam, .startGame:
            playerId == room.hostId
        case .joinTeam, .leaveTeam, .submitWords:
            room.players.contains { $0.id == playerId }
        }
    }

    // MARK: - Players
    /// Admits a player while the lobby is open. Rejects an id already in the
    /// room so a peer cannot impersonate an existing player.
    public static func addPlayer(_ player: OnlinePlayer, to room: GameRoom) -> GameRoom? {
        guard room.status.isLobby, !room.players.contains(where: { $0.id == player.id }) else { return nil }
        var next = room
        next.players.append(player)
        return next.canonicallyOrdered()
    }

    /// In the lobby a departing player is removed outright. Mid-game they
    /// stay on their team, marked disconnected, so explainer rotation is
    /// unchanged and the host may cover their turn.
    public static func playerLeft(_ playerId: String, from room: GameRoom) -> GameRoom? {
        guard let index = room.players.firstIndex(where: { $0.id == playerId }) else { return nil }
        var next = room
        if room.status.isLobby {
            next.players.remove(at: index)
            for teamIndex in next.teams.indices {
                next.teams[teamIndex].playerIds.removeAll { $0 == playerId }
            }
        } else {
            guard next.players[index].isConnected else { return nil }
            next.players[index].isConnected = false
        }
        return next.canonicallyOrdered()
    }

    // MARK: - Teams
    public static func joinTeam(_ teamId: String, playerId: String, in room: GameRoom) -> GameRoom? {
        guard room.status.isLobby,
              let playerIndex = room.players.firstIndex(where: { $0.id == playerId }),
              room.players[playerIndex].teamId != teamId,
              room.teams.contains(where: { $0.id == teamId }) else { return nil }
        var next = room
        next.players[playerIndex].teamId = teamId
        for teamIndex in next.teams.indices {
            next.teams[teamIndex].playerIds.removeAll { $0 == playerId }
            if next.teams[teamIndex].id == teamId {
                next.teams[teamIndex].playerIds.append(playerId)
            }
        }
        return next.canonicallyOrdered()
    }

    public static func leaveTeam(playerId: String, in room: GameRoom) -> GameRoom? {
        guard room.status.isLobby,
              let playerIndex = room.players.firstIndex(where: { $0.id == playerId }),
              room.players[playerIndex].teamId != nil else { return nil }
        var next = room
        next.players[playerIndex].teamId = nil
        for teamIndex in next.teams.indices {
            next.teams[teamIndex].playerIds.removeAll { $0 == playerId }
        }
        return next.canonicallyOrdered()
    }

    public static func createTeam(_ team: OnlineTeam, in room: GameRoom) -> GameRoom? {
        guard room.status.isLobby, !room.teams.contains(where: { $0.id == team.id }) else { return nil }
        var next = room
        next.teams.append(team)
        return next.canonicallyOrdered()
    }

    /// Removes a team and unassigns its members in the same step, so no
    /// player is left pointing at a team that no longer exists.
    public static func removeTeam(_ teamId: String, in room: GameRoom) -> GameRoom? {
        guard room.status.isLobby, room.teams.contains(where: { $0.id == teamId }) else { return nil }
        var next = room
        next.teams.removeAll { $0.id == teamId }
        for index in next.players.indices where next.players[index].teamId == teamId {
            next.players[index].teamId = nil
        }
        return next.canonicallyOrdered()
    }

    /// Players whose `teamId` points at `teamId`, the authoritative side of
    /// the relationship.
    public static func members(ofTeam teamId: String, in room: GameRoom) -> [OnlinePlayer] {
        room.players.filter { $0.teamId == teamId }
    }

    // MARK: - Starting
    /// At least two teams, each with at least two players.
    public static func canStartGame(_ room: GameRoom) -> Bool {
        guard room.teams.count >= minimumTeams else { return false }
        return room.teams.allSatisfy { members(ofTeam: $0.id, in: room).count >= minimumPlayersPerTeam }
    }

    public static func startGame(_ room: GameRoom) -> GameRoom? {
        guard room.status.isLobby, canStartGame(room) else { return nil }
        var next = room
        next.status = .playing
        return next
    }

    // MARK: - Words
    /// Opens the player's submission gate once. A second submission is
    /// rejected so a double tap cannot put the same words in the hat twice.
    public static func submitWords(playerId: String, in room: GameRoom) -> GameRoom? {
        guard room.status == .playing,
              room.gameState == nil,
              let index = room.players.firstIndex(where: { $0.id == playerId }),
              !room.players[index].hasSubmittedWords else { return nil }
        var next = room
        next.players[index].hasSubmittedWords = true
        return next
    }

    /// The host generated the pool for everyone, so every gate opens at once.
    public static func markAllWordsSubmitted(in room: GameRoom) -> GameRoom? {
        guard room.status == .playing, room.gameState == nil else { return nil }
        var next = room
        for index in next.players.indices {
            next.players[index].hasSubmittedWords = true
        }
        return next
    }

    /// True once every player's submission gate is open.
    public static func allWordsSubmitted(_ room: GameRoom) -> Bool {
        !room.players.isEmpty && room.players.allSatisfy(\.hasSubmittedWords)
    }
}
