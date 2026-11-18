//
//  GameConfiguration.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Observation
import SwiftUI

/// Where a game's words come from.
enum WordSource: CaseIterable {
    /// Players type in their own words (the word-input flow).
    case manual
    /// Words are chosen automatically from the bundled database.
    case automatic
}

/// The user's defaults for a new game. Injected into `GameConfiguration`
/// so the setup flow never reads the `AppConfiguration` singleton itself.
nonisolated struct GameDefaults: Sendable, Equatable {
    var wordsPerPlayer = 10
    var roundDuration = 60
    var isSkippingEnabled = true
    var skipPenalty = GameRules.defaultSkipPenalty
    var allowsDuplicateWords = false

    static let standard = GameDefaults()
}

/// The single-device game being set up: teams, words, and settings. Once the
/// game starts, `GameEngine` owns a frozen copy as its `GameState`.
@Observable
final class GameConfiguration {
    let minTeams = 2
    let maxTeams: Int
    let maxTeamMembers: Int
    var playersPerTeam: Int
    var wordsPerPlayer: Int
    var roundDuration: Int
    var isSkippingEnabled: Bool
    /// Points a team loses for each skipped word.
    var skipPenalty: Int
    /// Whether two players may put the same word in the hat.
    let allowsDuplicateWords: Bool
    var wordSource: WordSource
    var teams: [Team] = []
    var words: [Word] = []

    init(
        defaults: GameDefaults = .standard,
        maxTeams: Int = 6,
        maxTeamMembers: Int = 6,
        playersPerTeam: Int = 2,
        wordsPerPlayer: Int? = nil,
        roundDuration: Int? = nil,
        isSkippingEnabled: Bool? = nil,
        skipPenalty: Int? = nil,
        wordSource: WordSource = .manual,
        teams: [Team] = [],
        words: [Word] = []
    ) {
        self.maxTeams = maxTeams
        self.maxTeamMembers = maxTeamMembers
        self.playersPerTeam = playersPerTeam
        self.wordsPerPlayer = wordsPerPlayer ?? defaults.wordsPerPlayer
        self.roundDuration = roundDuration ?? defaults.roundDuration
        self.isSkippingEnabled = isSkippingEnabled ?? defaults.isSkippingEnabled
        self.skipPenalty = skipPenalty ?? defaults.skipPenalty
        self.allowsDuplicateWords = defaults.allowsDuplicateWords
        self.wordSource = wordSource
        self.teams = teams
        self.words = words
    }

    var players: [Player] {
        teams.flatMap(\.players)
    }

    var settings: GameState.Settings {
        GameState.Settings(
            roundDuration: roundDuration,
            isSkippingEnabled: isSkippingEnabled,
            skipPenalty: isSkippingEnabled ? skipPenalty : 0
        )
    }

    /// A not-yet-started game with this configuration's teams, words, and settings.
    func makeGameState() -> GameState {
        GameState(settings: settings, teams: teams, words: words)
    }
}

// MARK: - Restoring
extension GameConfiguration {
    /// Rebuilds the setup a saved game was started from, so Play Again and
    /// New Words keep working after a relaunch.
    convenience init(restoring state: GameState, defaults: GameDefaults) {
        let playerCount = state.teams.flatMap(\.players).count
        self.init(
            defaults: defaults,
            playersPerTeam: state.teams.first?.players.count ?? 2,
            wordsPerPlayer: playerCount > 0 ? max(1, state.words.count / playerCount) : nil,
            roundDuration: state.settings.roundDuration,
            isSkippingEnabled: state.settings.isSkippingEnabled,
            skipPenalty: state.settings.isSkippingEnabled ? state.settings.skipPenalty : nil,
            teams: state.teams,
            words: state.words
        )
    }
}

// MARK: - Mock data
extension GameConfiguration {
    /// A *fresh* mock configuration on every access. Must not be a stored
    /// `static let`: `GameConfiguration` is a reference type, so a shared
    /// instance would leak one game's words (and other mutable state) into
    /// the next game played in test mode.
    static var mockForTesting: GameConfiguration { makeMockForTesting() }

    private static func makeMockForTesting() -> GameConfiguration {
        let team1Id = UUID()
        let team1 = Team(
            id: team1Id,
            name: "Alpha",
            players: [
                .init(name: "Alice", teamId: team1Id),
                .init(name: "Bob", teamId: team1Id),
            ],
            color: TeamDefaultColorGenerator.defaultColors[0]
        )

        let team2Id = UUID()
        let team2 = Team(
            id: team2Id,
            name: "Beta",
            players: [
                .init(name: "John", teamId: team2Id),
                .init(name: "Margaret", teamId: team2Id),
            ],
            color: TeamDefaultColorGenerator.defaultColors[1]
        )

        return GameConfiguration(
            maxTeams: 10,
            maxTeamMembers: 6,
            playersPerTeam: 2,
            wordsPerPlayer: 3,
            roundDuration: 10,
            teams: [team1, team2],
            words: []
        )
    }
}
