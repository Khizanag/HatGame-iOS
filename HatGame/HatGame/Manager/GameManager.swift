//
//  GameManager.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Observation
import SwiftUI

/// The single-device game the setup and play screens share: the editable
/// `configuration` during setup, and the `engine` that runs the game once it
/// starts. All game rules live in `GameRules`; this type only wires setup
/// into the engine.
@Observable
final class GameManager {
    var configuration: GameConfiguration
    let engine: GameEngine

    init(
        configuration: GameConfiguration = GameConfiguration(),
        store: any GameStore = FileGameStore.shared,
        sound: (any SoundPlaying)? = nil,
        clock: any Clock<Duration> = ContinuousClock(),
        generator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.configuration = configuration
        engine = GameEngine(
            state: configuration.makeGameState(),
            clock: clock,
            generator: generator,
            store: store,
            sound: sound ?? SoundPlayer.shared
        )
    }

    /// Resumes a saved game; the engine comes back paused if it was mid-turn.
    init(
        restoring state: GameState,
        defaults: GameDefaults = .standard,
        store: any GameStore = FileGameStore.shared,
        sound: (any SoundPlaying)? = nil,
        clock: any Clock<Duration> = ContinuousClock(),
        generator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        configuration = GameConfiguration(restoring: state, defaults: defaults)
        engine = GameEngine(
            state: state,
            clock: clock,
            generator: generator,
            store: store,
            sound: sound ?? SoundPlayer.shared
        )
    }
}

// MARK: - Teams
extension GameManager {
    func addTeam(_ team: Team) {
        configuration.teams.append(team)
    }

    func removeTeam(_ team: Team) {
        configuration.teams.removeAll { $0.id == team.id }
        configuration.words.removeAll { word in
            team.players.contains { $0.id == word.authorId }
        }
    }

    /// Replaces a team in place, preserving its position in the list.
    func updateTeam(_ team: Team) {
        guard let index = configuration.teams.firstIndex(where: { $0.id == team.id }) else { return }
        configuration.teams[index] = team
    }

    func moveTeam(from source: IndexSet, to destination: Int) {
        configuration.teams.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Words
extension GameManager {
    /// Sets `player`'s words in the hat, replacing any they saved before — so
    /// saving the same player twice never duplicates their words.
    func setWords(_ texts: [String], for player: Player) {
        configuration.words.removeAll { $0.authorId == player.id }
        configuration.words.append(contentsOf: texts.map { Word(text: $0, authorId: player.id) })
    }

    /// Words other players have already put in the hat.
    func wordTexts(excluding player: Player) -> [String] {
        configuration.words
            .filter { $0.authorId != player.id }
            .map(\.text)
    }

    /// Replaces the hat with `count` distinct words drawn from `pool`.
    /// Used by the automatic word source, where players don't type words in.
    func fillRandomWords(count: Int, from pool: [String]) {
        configuration.words = WordEntryRules.distinct(pool.shuffled(), limit: count).map { Word(text: $0) }
    }
}

// MARK: - Game lifecycle
extension GameManager {
    /// Starts the game. Repeated calls (a double tap) are ignored by the engine.
    func startGame(startingTeamIndex: Int) {
        engine.start(configuration.makeGameState(), startingTeamIndex: startingTeamIndex)
    }

    /// Play Again: same teams, same words, scores reset.
    func rematch() {
        engine.rematch()
    }

    /// New Words: same teams, the hat is emptied for fresh words.
    func startOverWithNewWords() {
        configuration.words = []
        engine.newWords()
    }
}
