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

    /// The record this device already holds in the room — a player coming
    /// back after a dropped connection or a restart. Same device, same seat.
    public static func returningPlayer(deviceId: String, in room: GameRoom) -> OnlinePlayer? {
        room.players.first { $0.deviceId == deviceId }
    }

    /// Admits a nearby guest from its self-declared hello. A device whose
    /// record is in the room and not bound to another live peer gets that
    /// record back, team and words intact, at any point in the game. Anyone
    /// else joins only while the lobby is open, as a fresh player: the host
    /// owns team, submission, presence, and join time, so a guest cannot
    /// claim a team, skip word entry, or seniority for host failover. The
    /// host's own record is never handed out.
    public static func admitGuest(
        _ declared: OnlinePlayer,
        to room: GameRoom,
        now: Date,
        boundPlayerIds: Set<String>
    ) -> GuestAdmission {
        if let returning = returningPlayer(deviceId: declared.deviceId, in: room),
           returning.id != room.hostId,
           !boundPlayerIds.contains(returning.id),
           let index = room.players.firstIndex(where: { $0.id == returning.id }) {
            var next = room
            next.players[index].isConnected = true
            return .admitted(next, playerId: returning.id)
        }
        guard room.status.isLobby else { return .refused(.gameInProgress) }
        let fresh = OnlinePlayer(
            id: declared.id,
            deviceId: declared.deviceId,
            name: declared.name,
            joinedAt: now
        )
        guard let next = addPlayer(fresh, to: room) else { return .refused(.duplicate) }
        return .admitted(next, playerId: fresh.id)
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

    /// What `playerId`'s device still has to do to get a started game
    /// going, or `nil` when it has nothing to do. Only the host generates
    /// the automatic pool — two devices drawing words would fill the hat
    /// twice — while the first state may be written by anyone who can act
    /// as host, since that write is a create-if-absent transaction.
    /// `startsWithSubmittedWords` is the host's choice not to wait for
    /// players who have not submitted; it counts once anyone has.
    public static func pendingSetupStep(
        in room: GameRoom,
        for playerId: String,
        startsWithSubmittedWords: Bool = false
    ) -> GameSetupStep? {
        guard room.status == .playing, room.gameState == nil else { return nil }
        let isReady = allWordsSubmitted(room) || (startsWithSubmittedWords && anyWordsSubmitted(room))
        if room.settings.isAutomaticWords, !isReady {
            return playerId == room.hostId ? .generateWords : nil
        }
        guard isReady,
              OnlineGameRules.canActAsHost(playerId, hostId: room.hostId, players: room.players) else { return nil }
        return .initializeGame
    }

    /// True once every connected player's submission gate is open. A player
    /// who left or lost their connection is not waited for — otherwise one
    /// dropped phone holds the whole room on the waiting screen.
    public static func allWordsSubmitted(_ room: GameRoom) -> Bool {
        let present = room.players.filter(\.isConnected)
        return !present.isEmpty && present.allSatisfy(\.hasSubmittedWords)
    }

    public static func anyWordsSubmitted(_ room: GameRoom) -> Bool {
        room.players.contains(where: \.hasSubmittedWords)
    }

    /// The host may stop waiting and start with the words already in: typed
    /// words, someone has submitted, and someone still has not.
    public static func canStartWithSubmittedWords(_ room: GameRoom) -> Bool {
        room.status == .playing
            && room.gameState == nil
            && !room.settings.isAutomaticWords
            && anyWordsSubmitted(room)
            && !allWordsSubmitted(room)
    }
}

/// Host-side work between pressing Start and the first turn.
public enum GameSetupStep: Equatable, Sendable {
    /// Draw the automatic word pool for everyone.
    case generateWords
    /// Write the first game state from the submitted words.
    case initializeGame
}

/// The host's answer to a nearby guest's hello.
public enum GuestAdmission: Sendable {
    case admitted(GameRoom, playerId: String)
    case refused(Refusal)

    public enum Refusal: Equatable, Sendable {
        /// The game has started and the device holds no seat in it.
        case gameInProgress
        /// The declared id is already taken.
        case duplicate
    }
}
