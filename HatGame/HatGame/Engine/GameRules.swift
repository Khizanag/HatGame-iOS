//
//  GameRules.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// The single-device game's rules as pure transitions over `GameState`.
///
/// Every transition first checks that it is valid in the current phase and
/// returns the state unchanged when it is not, so a repeated or late call (a
/// double tap, a tap landing at expiry) can never advance the game twice.
/// The canonical rules are in `docs/turn.md` and `docs/rounds.md`.
nonisolated enum GameRules {
    // MARK: - Game lifecycle
    /// The fewest teams a game can start with (`docs/setup.md`).
    static let minimumTeams = 2
    /// The fewest players a team needs: one explains, at least one guesses.
    static let minimumPlayersPerTeam = 2

    /// Whether a game can start from `state`: enough teams, every one with an
    /// explainer and a guesser, and words in the hat.
    static func canStart(_ state: GameState) -> Bool {
        state.phase == .setup
            && !state.words.isEmpty
            && state.settings.roundDuration > 0
            && state.teams.count >= minimumTeams
            && state.teams.allSatisfy { $0.players.count >= minimumPlayersPerTeam }
    }

    /// Starts round one with `startingTeamIndex` up. Requires `canStart`.
    static func start(
        _ state: GameState,
        startingTeamIndex: Int,
        using generator: inout some RandomNumberGenerator
    ) -> GameState {
        guard canStart(state),
              let startingTeam = state.teams[safe: startingTeamIndex] ?? state.teams.first
        else { return state }

        var next = resetProgress(state)
        next.phase = .nextTeam
        next.round = .first
        next.currentTeamId = startingTeam.id
        next.remainingWordIds = state.words.map(\.id).shuffled(using: &generator)
        return next
    }

    /// Back to `.setup` with the same teams and words and every score cleared.
    /// Only offered once the game is over, so a game in progress is never wiped.
    static func rematch(_ state: GameState) -> GameState {
        guard state.phase == .finished || state.phase == .setup else { return state }
        return resetProgress(state)
    }

    /// Abandons a game in progress: back to `.setup` with every score cleared,
    /// so nothing is left to resume.
    static func abandon(_ state: GameState) -> GameState {
        guard state.phase.isInProgress else { return state }
        return resetProgress(state)
    }

    /// Like `rematch`, but the hat is emptied so players add new words.
    static func newWords(_ state: GameState) -> GameState {
        guard state.phase == .finished || state.phase == .setup else { return state }
        var next = resetProgress(state)
        next.words = []
        return next
    }

    // MARK: - Turn
    /// Starts the current team's turn. On a team's first turn `explainerIndex`
    /// picks its explainer; afterwards the team is locked and the index is
    /// ignored. A team that emptied the hat last round resumes with its
    /// carried-over time; everyone else gets a full timer.
    static func beginTurn(
        _ state: GameState,
        explainerIndex: Int?,
        using generator: inout some RandomNumberGenerator
    ) -> GameState {
        guard state.phase == .nextTeam, let team = state.currentTeam,
              let firstWord = state.remainingWordIds.randomElement(using: &generator)
        else { return state }

        var next = state
        if next.canSelectExplainer(for: team) {
            let chosen = explainerIndex.flatMap { team.players.indices.contains($0) ? $0 : nil }
            next.explainerIndices[team.id] = chosen ?? next.explainerIndices[team.id] ?? 0
            next.lockedTeamIds.insert(team.id)
        }
        let seconds = next.carryOverSeconds.removeValue(forKey: team.id) ?? state.settings.roundDuration
        next.turn = GameState.Turn(teamId: team.id, remaining: .seconds(seconds))
        next.currentWordId = firstWord
        next.phase = .playing
        return next
    }

    /// Scores the current word. Emptying the hat ends the turn and the round;
    /// the team keeps the time it had left (see `carryOverSeconds(for:)`).
    static func guess(
        _ state: GameState,
        remaining: Duration,
        using generator: inout some RandomNumberGenerator
    ) -> GameState {
        guard isRunning(state), remaining > .zero, var turn = state.turn,
              let wordId = state.currentWordId
        else { return state }

        var next = state
        next.scores[state.round, default: [:]][turn.teamId, default: []].append(wordId)
        next.remainingWordIds.removeAll { $0 == wordId }
        turn.guessedWordIds.append(wordId)
        turn.remaining = remaining

        if let nextWord = next.remainingWordIds.randomElement(using: &generator) {
            next.currentWordId = nextWord
            next.turn = turn
        } else {
            next.carryOverSeconds[turn.teamId] = carryOverSeconds(for: remaining)
            turn.endReason = .allWordsGuessed
            next.turn = turn
            next.currentWordId = nil
            next.phase = .turnResults
        }
        return next
    }

    /// Puts the current word back and shows a different one. Needs skipping
    /// enabled and at least two words in the hat.
    static func skip(
        _ state: GameState,
        using generator: inout some RandomNumberGenerator
    ) -> GameState {
        guard canSkip(state), let wordId = state.currentWordId,
              let nextWord = state.remainingWordIds.filter({ $0 != wordId }).randomElement(using: &generator)
        else { return state }

        var next = state
        next.currentWordId = nextWord
        return next
    }

    static func pause(_ state: GameState, remaining: Duration) -> GameState {
        guard isRunning(state) else { return state }
        var next = state
        next.turn?.isPaused = true
        next.turn?.remaining = max(remaining, .zero)
        return next
    }

    static func resume(_ state: GameState) -> GameState {
        guard state.phase == .playing, state.turn?.isPaused == true else { return state }
        var next = state
        next.turn?.isPaused = false
        return next
    }

    /// Records the live clock's reading without changing anything else.
    static func snapshot(_ state: GameState, remaining: Duration) -> GameState {
        guard state.phase == .playing else { return state }
        var next = state
        next.turn?.remaining = max(remaining, .zero)
        return next
    }

    /// The clock ran out. Words left in the hat stay there.
    static func expire(_ state: GameState) -> GameState {
        endTurn(state, reason: .timeExpired, remaining: .zero)
    }

    /// The team gave up — treated exactly like the clock running out.
    static func giveUp(_ state: GameState, remaining: Duration) -> GameState {
        endTurn(state, reason: .gaveUp, remaining: remaining)
    }

    /// Leaves the turn results: the next team in the same round, the next
    /// round (the team that emptied the hat starts it), or the final results.
    static func continueAfterTurn(_ state: GameState) -> GameState {
        guard state.phase == .turnResults, let turn = state.turn,
              let team = state.team(withId: turn.teamId)
        else { return state }

        var next = state
        next.turn = nil
        next.currentWordId = nil

        guard turn.endReason == .allWordsGuessed else {
            next.explainerIndices[team.id] = rotatedExplainerIndex(for: team, in: state)
            next.currentTeamId = nextTeamId(after: team.id, in: state)
            next.phase = .nextTeam
            return next
        }

        next.carryOverSeconds = next.carryOverSeconds.filter { $0.key == team.id }
        guard let nextRound = state.round.next else {
            next.carryOverSeconds = [:]
            next.phase = .finished
            return next
        }
        next.round = nextRound
        next.remainingWordIds = state.words.map(\.id)
        next.phase = .nextTeam
        return next
    }

    // MARK: - Queries
    static func canSkip(_ state: GameState) -> Bool {
        isRunning(state) && state.settings.isSkippingEnabled && state.remainingWordIds.count > 1
    }

    /// Whole seconds a team carries over after emptying the hat with
    /// `remaining` on the clock: the value its countdown was showing, rounded
    /// up and never below one second. A turn ends the instant the clock hits
    /// zero, so the hat can only be emptied with time still left.
    static func carryOverSeconds(for remaining: Duration) -> Int {
        max(1, TurnClock.displayedSeconds(for: remaining))
    }
}

// MARK: - Private
nonisolated private extension GameRules {
    static func isRunning(_ state: GameState) -> Bool {
        state.phase == .playing && state.turn?.isPaused == false
    }

    static func endTurn(_ state: GameState, reason: PlayCompletionReason, remaining: Duration) -> GameState {
        guard state.phase == .playing else { return state }
        var next = state
        next.turn?.endReason = reason
        next.turn?.remaining = max(remaining, .zero)
        next.turn?.isPaused = false
        next.currentWordId = nil
        next.phase = .turnResults
        return next
    }

    static func resetProgress(_ state: GameState) -> GameState {
        var next = GameState(settings: state.settings, teams: state.teams, words: state.words)
        next.schemaVersion = state.schemaVersion
        return next
    }

    static func rotatedExplainerIndex(for team: Team, in state: GameState) -> Int {
        guard !team.players.isEmpty else { return 0 }
        let current = state.explainerIndices[team.id] ?? 0
        return (current + 1) % team.players.count
    }

    static func nextTeamId(after teamId: Team.ID, in state: GameState) -> Team.ID? {
        guard let index = state.teams.firstIndex(where: { $0.id == teamId }) else {
            return state.teams.first?.id
        }
        return state.teams[(index + 1) % state.teams.count].id
    }
}
