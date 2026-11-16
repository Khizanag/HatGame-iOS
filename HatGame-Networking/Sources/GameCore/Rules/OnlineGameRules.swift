//
//  OnlineGameRules.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// Pure turn and round transitions for multiplayer games (see `docs/turn.md`
/// and `docs/rounds.md`). Every transition returns `nil` when its
/// precondition fails, so a stale or duplicated request is a no-op rather
/// than a corrupting write.
public enum OnlineGameRules {
    /// How long after the deadline a guess still counts, absorbing the time
    /// between the tap and the write landing.
    public static let guessGraceSeconds: TimeInterval = 2
    /// How long after the deadline the host may end a turn the explainer
    /// failed to close.
    public static let stallGraceSeconds: TimeInterval = 3

    // MARK: - Entry point
    /// Applies `action` on behalf of `playerId` if they are allowed to and its
    /// precondition holds.
    public static func apply(
        _ action: GameAction,
        by playerId: String,
        to state: OnlineGameState,
        context: GameContext,
        shuffle: ([String]) -> [String] = { $0.shuffled() }
    ) -> OnlineGameState? {
        guard canPerform(action, by: playerId, state: state, context: context) else { return nil }
        return reduce(state, action, context: context, shuffle: shuffle)
    }

    /// Applies `action` without an authority check.
    public static func reduce(
        _ state: OnlineGameState,
        _ action: GameAction,
        context: GameContext,
        shuffle: ([String]) -> [String] = { $0.shuffled() }
    ) -> OnlineGameState? {
        switch action {
        case .startTurn:
            startTurn(state, teams: context.teams, now: context.now)
        case let .markGuessed(wordId):
            markGuessed(state, expectedWordId: wordId, teams: context.teams, now: context.now)
        case let .skip(wordId):
            skip(state, expectedWordId: wordId)
        case .endTurn:
            endTurn(state)
        case .advanceAfterTurnResults:
            advanceAfterTurnResults(state, teams: context.teams, players: context.players)
        case .advanceAfterRoundResults:
            advanceAfterRoundResults(state, teams: context.teams, players: context.players, shuffle: shuffle)
        }
    }

    // MARK: - Authority
    /// The explainer drives their own turn. The host may stand in when the
    /// explainer is offline or their timer has run well past zero, so one
    /// backgrounded device cannot wedge the room. Only the host moves
    /// between rounds. "Host" here means anyone `canActAsHost` admits, so a
    /// host who drops out does not wedge the room either.
    public static func canPerform(
        _ action: GameAction,
        by playerId: String,
        state: OnlineGameState,
        context: GameContext
    ) -> Bool {
        let isActive = state.activePlayerId == playerId
        let isHost = canActAsHost(playerId, hostId: context.hostId, players: context.players)
        let hostCanCover = isHost && isActivePlayerAway(state, players: context.players)

        switch action {
        case .startTurn, .markGuessed, .skip:
            return isActive
        case .endTurn:
            if isActive { return state.phase == .playing }
            guard isHost else { return false }
            return hostCanCover || (state.phase == .playing && isStalled(state, now: context.now))
        case .advanceAfterTurnResults:
            return isActive || hostCanCover
        case .advanceAfterRoundResults:
            return isHost
        }
    }

    /// Who stands in for the host: the host while connected; otherwise the
    /// longest-connected player still connected (earliest `joinedAt`, ties
    /// by id), which every device derives identically from the same room.
    /// Falls back to the host when nobody is connected.
    public static func actingHostId(hostId: String, players: [OnlinePlayer]) -> String {
        if players.first(where: { $0.id == hostId })?.isConnected == true { return hostId }
        let seniority = players.sorted { ($0.joinedAt, $0.id) < ($1.joinedAt, $1.id) }
        return seniority.first(where: \.isConnected)?.id ?? hostId
    }

    /// The host keeps host authority even while marked away — a stale flag
    /// must not lock them out — and the acting host shares it.
    public static func canActAsHost(_ playerId: String, hostId: String, players: [OnlinePlayer]) -> Bool {
        playerId == hostId || playerId == actingHostId(hostId: hostId, players: players)
    }

    /// True when nobody is explaining, or the explainer has left or lost
    /// their connection.
    public static func isActivePlayerAway(_ state: OnlineGameState, players: [OnlinePlayer]) -> Bool {
        guard let activeId = state.activePlayerId,
              let player = players.first(where: { $0.id == activeId }) else { return true }
        return !player.isConnected
    }

    /// True once the turn is past its deadline by more than the stall grace.
    public static func isStalled(_ state: OnlineGameState, now: Date) -> Bool {
        isPastDeadline(state, now: now, grace: stallGraceSeconds)
    }

    // MARK: - Setup
    /// The first `.teamPrep` state: the starting team — drawn at random
    /// unless `startingTeamIndex` names one — plays first, with its first
    /// player explaining. `wordIds` arrive already shuffled.
    public static func initialState(
        teams: [OnlineTeam],
        players: [OnlinePlayer],
        wordIds: [String],
        settings: GameSettings,
        startingTeamIndex: Int? = nil
    ) -> OnlineGameState? {
        guard !teams.isEmpty, !wordIds.isEmpty else { return nil }
        let startIndex = normalizedIndex(startingTeamIndex ?? Int.random(in: teams.indices), count: teams.count)
        let firstTeam = teams[startIndex]
        var scores: [String: [OnlineGameRound: Int]] = [:]
        var explainerIndices: [String: Int] = [:]
        for team in teams {
            scores[team.id] = [.first: 0, .second: 0, .third: 0]
            explainerIndices[team.id] = 0
        }
        var state = OnlineGameState(
            currentRound: .first,
            currentTeamIndex: startIndex,
            teamExplainerIndices: explainerIndices,
            currentWordId: wordIds.first,
            remainingWordIds: wordIds,
            allWordIds: wordIds,
            scores: scores,
            phase: .teamPrep,
            roundDuration: settings.roundDuration,
            isSkippingEnabled: settings.isSkippingEnabled
        )
        assignExplainer(of: firstTeam, in: &state, players: players)
        return state
    }

    // MARK: - Turn
    /// `.teamPrep` → `.playing`, anchoring every peer's countdown at `now`.
    /// A team that emptied the hat last round plays this turn on its
    /// carried-over seconds; everyone else gets a full timer.
    public static func startTurn(_ state: OnlineGameState, teams: [OnlineTeam], now: Date) -> OnlineGameState? {
        guard state.isSupported,
              state.phase == .teamPrep,
              state.activePlayerId != nil,
              let firstWordId = state.remainingWordIds.first else { return nil }
        var next = state
        next.phase = .playing
        next.timerStartedAt = now
        next.turnSeconds = currentTeam(state, teams: teams)
            .flatMap { next.carryOverSeconds.removeValue(forKey: $0.id) }
            ?? state.roundDuration
        next.currentWordId = state.currentWordId ?? firstWordId
        return next
    }

    /// Scores the current word for the current team and draws the next one.
    /// Guessing the last word empties the hat and ends the turn in the same
    /// transition.
    public static func markGuessed(
        _ state: OnlineGameState,
        expectedWordId: String,
        teams: [OnlineTeam],
        now: Date
    ) -> OnlineGameState? {
        guard state.isSupported,
              state.phase == .playing,
              state.currentWordId == expectedWordId,
              state.remainingWordIds.contains(expectedWordId),
              let team = currentTeam(state, teams: teams),
              !isPastDeadline(state, now: now, grace: guessGraceSeconds) else { return nil }
        var next = state
        next.scores[team.id, default: [:]][state.currentRound, default: 0] += 1
        next.remainingWordIds.removeAll { $0 == expectedWordId }
        next.currentWordId = next.remainingWordIds.first
        if next.remainingWordIds.isEmpty {
            if let deadline = deadline(state) {
                next.carryOverSeconds[team.id] = carryOverSeconds(remaining: deadline.timeIntervalSince(now))
            }
            next.phase = .turnResults
            next.timerStartedAt = nil
            next.turnSeconds = nil
        }
        return next
    }

    /// Whole seconds a team carries after emptying the hat with `remaining`
    /// on the clock: what its countdown showed, rounded up, never below one
    /// — a guess accepted in the grace period after zero still carries one.
    /// Matches the single-device `GameRules.carryOverSeconds(for:)`.
    public static func carryOverSeconds(remaining: TimeInterval) -> Int {
        max(1, Int(remaining.rounded(.up)))
    }

    /// Moves the current word to the back of the hat. Allowed only when the
    /// game enables skipping and another word remains to show instead.
    public static func skip(_ state: OnlineGameState, expectedWordId: String) -> OnlineGameState? {
        guard state.isSupported,
              state.phase == .playing,
              state.isSkippingEnabled,
              state.currentWordId == expectedWordId,
              state.remainingWordIds.count > 1,
              state.remainingWordIds.contains(expectedWordId) else { return nil }
        var next = state
        next.remainingWordIds.removeAll { $0 == expectedWordId }
        next.remainingWordIds.append(expectedWordId)
        next.currentWordId = next.remainingWordIds.first
        return next
    }

    /// Time's up or give up. From `.teamPrep` this forfeits a turn whose
    /// explainer is away; `canPerform` limits that path to the host.
    public static func endTurn(_ state: OnlineGameState) -> OnlineGameState? {
        guard state.isSupported, state.phase == .playing || state.phase == .teamPrep else { return nil }
        var next = state
        next.phase = .turnResults
        next.timerStartedAt = nil
        next.turnSeconds = nil
        return next
    }

    // MARK: - Advancement
    /// After turn results: an empty hat ends the round with the same team and
    /// explainer in place; otherwise the team that just played rotates its
    /// explainer and the next team takes the hat.
    public static func advanceAfterTurnResults(
        _ state: OnlineGameState,
        teams: [OnlineTeam],
        players: [OnlinePlayer]
    ) -> OnlineGameState? {
        guard state.isSupported, state.phase == .turnResults, !teams.isEmpty else { return nil }
        var next = state
        next.timerStartedAt = nil

        if state.remainingWordIds.isEmpty {
            next.phase = .roundResults
            return next
        }

        if let previousTeam = currentTeam(state, teams: teams) {
            let teamSize = max(playersInTeam(previousTeam, allPlayers: players).count, 1)
            next.teamExplainerIndices[previousTeam.id] = (state.explainerIndex(for: previousTeam.id) + 1) % teamSize
        }
        next.currentTeamIndex = (normalizedIndex(state.currentTeamIndex, count: teams.count) + 1) % teams.count
        assignExplainer(of: teams[next.currentTeamIndex], in: &next, players: players)
        next.phase = .teamPrep
        next.currentWordId = next.remainingWordIds.first
        return next
    }

    /// After round results: refill the hat for the next round, keeping the
    /// team that emptied it and its explainer, or finish after round three.
    public static func advanceAfterRoundResults(
        _ state: OnlineGameState,
        teams: [OnlineTeam],
        players: [OnlinePlayer],
        shuffle: ([String]) -> [String] = { $0.shuffled() }
    ) -> OnlineGameState? {
        guard state.isSupported, state.phase == .roundResults else { return nil }
        var next = state
        next.timerStartedAt = nil

        guard let upcoming = state.currentRound.next else {
            next.carryOverSeconds = [:]
            next.phase = .finished
            return next
        }

        // Only the team that emptied the hat carries time into the round.
        let starterId = currentTeam(state, teams: teams)?.id
        next.carryOverSeconds = state.carryOverSeconds.filter { $0.key == starterId }
        next.currentRound = upcoming
        next.remainingWordIds = shuffle(state.allWordIds)
        next.currentWordId = next.remainingWordIds.first
        if let team = currentTeam(state, teams: teams) {
            assignExplainer(of: team, in: &next, players: players)
        } else {
            next.activePlayerId = nil
        }
        next.phase = .teamPrep
        return next
    }

    // MARK: - Queries
    /// A team's players in explaining order. `player.teamId` decides
    /// membership; `team.playerIds` only orders it, so a lost concurrent
    /// update to that list can neither drop nor duplicate a member.
    public static func playersInTeam(_ team: OnlineTeam, allPlayers: [OnlinePlayer]) -> [OnlinePlayer] {
        let members = allPlayers.filter { $0.teamId == team.id }
        let lookup = Dictionary(members.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen: Set<String> = []
        let ordered = team.playerIds.compactMap { id -> OnlinePlayer? in
            guard seen.insert(id).inserted else { return nil }
            return lookup[id]
        }
        return ordered + members.filter { !seen.contains($0.id) }
    }

    public static func currentTeam(_ state: OnlineGameState, teams: [OnlineTeam]) -> OnlineTeam? {
        teams.indices.contains(state.currentTeamIndex) ? teams[state.currentTeamIndex] : nil
    }

    /// The player whose turn it is to explain for `team`: the one the
    /// rotation points at, or the next connected member after them. An away
    /// player explains only when nobody on the team is connected.
    public static func explainer(
        for team: OnlineTeam,
        state: OnlineGameState,
        players: [OnlinePlayer]
    ) -> OnlinePlayer? {
        let members = playersInTeam(team, allPlayers: players)
        return explainerPosition(in: members, from: state.explainerIndex(for: team.id)).map { members[$0] }
    }

    /// When the running turn's timer reaches zero, or `nil` between turns.
    public static func deadline(_ state: OnlineGameState) -> Date? {
        state.timerStartedAt?.addingTimeInterval(TimeInterval(turnDuration(state)))
    }

    /// Seconds on the running turn's clock when it started.
    public static func turnDuration(_ state: OnlineGameState) -> Int {
        state.turnSeconds ?? state.roundDuration
    }

    // MARK: - Helpers
    /// Points `team`'s rotation at its explainer and makes them the active
    /// player. Storing the skipped-to position keeps the rotation moving on
    /// from whoever actually explained.
    private static func assignExplainer(of team: OnlineTeam, in state: inout OnlineGameState, players: [OnlinePlayer]) {
        let members = playersInTeam(team, allPlayers: players)
        guard let position = explainerPosition(in: members, from: state.explainerIndex(for: team.id)) else {
            state.activePlayerId = nil
            return
        }
        state.teamExplainerIndices[team.id] = position
        state.activePlayerId = members[position].id
    }

    private static func explainerPosition(in members: [OnlinePlayer], from index: Int) -> Int? {
        guard !members.isEmpty else { return nil }
        let start = normalizedIndex(index, count: members.count)
        let rotation = (0..<members.count).map { (start + $0) % members.count }
        return rotation.first { members[$0].isConnected } ?? start
    }

    private static func isPastDeadline(_ state: OnlineGameState, now: Date, grace: TimeInterval) -> Bool {
        guard let deadline = deadline(state) else { return false }
        return now > deadline.addingTimeInterval(grace)
    }

    private static func normalizedIndex(_ index: Int, count: Int) -> Int {
        ((index % count) + count) % count
    }
}
