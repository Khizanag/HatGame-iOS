//
//  Fixtures.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import HatGame

enum Fixtures {
    static let teamNames = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"]

    static func teams(count: Int = 2, playersPerTeam: Int = 2) -> [Team] {
        (0..<count).map { index in
            let id = UUID()
            let players = (0..<playersPerTeam).map { Player(name: "P\(index)-\($0)", teamId: id) }
            return Team(
                id: id,
                name: teamNames[index % teamNames.count],
                players: players,
                teamColor: TeamColor(red: Double(index) / 10, green: 0.5, blue: 0.5)
            )
        }
    }

    static func words(_ texts: [String] = ["one", "two", "three"]) -> [Word] {
        texts.map { Word(text: $0) }
    }

    static func state(
        teams: [Team] = Fixtures.teams(),
        words: [Word] = Fixtures.words(),
        roundDuration: Int = 60,
        isSkippingEnabled: Bool = true
    ) -> GameState {
        GameState(
            settings: GameState.Settings(roundDuration: roundDuration, isSkippingEnabled: isSkippingEnabled),
            teams: teams,
            words: words
        )
    }

    /// A game at Next Team for the first team.
    static func started(
        teams: [Team] = Fixtures.teams(),
        words: [Word] = Fixtures.words(),
        roundDuration: Int = 60,
        isSkippingEnabled: Bool = true,
        startingTeamIndex: Int = 0
    ) -> GameState {
        var generator = SeededGenerator()
        return GameRules.start(
            state(teams: teams, words: words, roundDuration: roundDuration, isSkippingEnabled: isSkippingEnabled),
            startingTeamIndex: startingTeamIndex,
            using: &generator
        )
    }

    /// A game with the first team's turn running.
    static func playing(
        teams: [Team] = Fixtures.teams(),
        words: [Word] = Fixtures.words(),
        roundDuration: Int = 60,
        isSkippingEnabled: Bool = true
    ) -> GameState {
        var generator = SeededGenerator()
        return GameRules.beginTurn(
            started(teams: teams, words: words, roundDuration: roundDuration, isSkippingEnabled: isSkippingEnabled),
            explainerIndex: 0,
            using: &generator
        )
    }
}

// MARK: - Playing helpers
extension GameState {
    /// Guesses until the hat is empty, with `remaining` on the clock.
    func guessingAll(remaining: Duration = .seconds(30)) -> GameState {
        var generator = SeededGenerator()
        var state = self
        while state.phase == .playing {
            state = GameRules.guess(state, remaining: remaining, using: &generator)
        }
        return state
    }

    /// Plays the current round to its end: the up team clears the hat in its turn.
    func clearingRound(remaining: Duration = .seconds(30)) -> GameState {
        var generator = SeededGenerator()
        let playing = GameRules.beginTurn(self, explainerIndex: 0, using: &generator)
        return GameRules.continueAfterTurn(playing.guessingAll(remaining: remaining))
    }
}
