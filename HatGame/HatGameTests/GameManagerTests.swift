//
//  GameManagerTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

@testable import HatGame
import SwiftUI
import Testing

@MainActor
@Suite("Game manager setup")
struct GameManagerTests {
    private let store = RecordingGameStore()

    // MARK: - Words
    @Test("Saving a player's words twice replaces them instead of duplicating (E8)")
    func setWordsIsIdempotent() throws {
        let manager = makeManager()
        let player = try #require(manager.configuration.players.first)

        manager.setWords(["cat", "dog"], for: player)
        manager.setWords(["cat", "dog"], for: player)

        #expect(manager.configuration.words.map(\.text) == ["cat", "dog"])
        #expect(manager.configuration.words.allSatisfy { $0.authorId == player.id })
    }

    @Test("Each player's words are kept separately")
    func wordsArePerPlayer() {
        let manager = makeManager()
        let players = manager.configuration.players
        manager.setWords(["cat"], for: players[0])
        manager.setWords(["dog", "owl"], for: players[1])

        manager.setWords(["fox"], for: players[0])

        #expect(Set(manager.configuration.words.map(\.text)) == ["fox", "dog", "owl"])
        #expect(manager.wordTexts(excluding: players[0]) == ["dog", "owl"])
    }

    @Test("Removing a team removes the words its players added")
    func removeTeamRemovesItsWords() {
        let manager = makeManager()
        let team = manager.configuration.teams[0]
        manager.setWords(["cat"], for: team.players[0])
        manager.setWords(["dog"], for: manager.configuration.teams[1].players[0])

        manager.removeTeam(team)

        #expect(manager.configuration.teams.count == 1)
        #expect(manager.configuration.words.map(\.text) == ["dog"])
    }

    @Test("Moving teams reorders them")
    func moveTeamReorders() {
        let manager = makeManager()
        let ids = manager.configuration.teams.map(\.id)

        manager.moveTeam(from: IndexSet(integer: 0), to: 2)

        #expect(manager.configuration.teams.map(\.id) == ids.reversed())
    }

    @Test("Automatic words are distinct, drawn from the pool, and capped by its size")
    func fillRandomWords() {
        let manager = makeManager()
        let pool = ["Apple", "apple", "pear", "plum", "fig"]

        manager.fillRandomWords(count: 3, from: pool)
        let texts = manager.configuration.words.map(\.text)
        #expect(texts.count == 3)
        #expect(Set(texts.map(WordEntryRules.normalized)).count == 3)
        #expect(texts.allSatisfy(pool.contains))

        manager.fillRandomWords(count: 10, from: pool)
        #expect(manager.configuration.words.count == 4)
    }

    // MARK: - Lifecycle
    @Test("New words empties the hat on both the setup and the engine")
    func startOverWithNewWords() {
        let manager = makeManager(words: Fixtures.words())
        manager.startGame(startingTeamIndex: 0)

        manager.startOverWithNewWords()

        #expect(manager.configuration.words.isEmpty)
        #expect(manager.engine.phase == .setup)
        #expect(manager.engine.state.words.isEmpty)
    }

    @Test("Restoring rebuilds the setup from the saved game")
    func restoringRebuildsConfiguration() {
        let saved = Fixtures.playing(
            teams: Fixtures.teams(count: 3, playersPerTeam: 3),
            words: Fixtures.words(Array(repeating: "w", count: 18)),
            roundDuration: 45,
            isSkippingEnabled: false
        )

        let manager = GameManager(restoring: saved, store: store, sound: SoundSpy())

        #expect(manager.configuration.teams == saved.teams)
        #expect(manager.configuration.words == saved.words)
        #expect(manager.configuration.playersPerTeam == 3)
        #expect(manager.configuration.wordsPerPlayer == 2)
        #expect(manager.configuration.roundDuration == 45)
        #expect(!manager.configuration.isSkippingEnabled)
        #expect(manager.engine.isPaused)
    }

    // MARK: - Defaults
    @Test("A configuration takes its values from the injected defaults")
    func configurationUsesInjectedDefaults() {
        let defaults = GameDefaults(
            wordsPerPlayer: 7,
            roundDuration: 30,
            isSkippingEnabled: false,
            allowsDuplicateWords: true
        )

        let configuration = GameConfiguration(defaults: defaults)

        #expect(configuration.wordsPerPlayer == 7)
        #expect(configuration.roundDuration == 30)
        #expect(!configuration.isSkippingEnabled)
        #expect(configuration.allowsDuplicateWords)
        #expect(configuration.settings == GameState.Settings(roundDuration: 30, isSkippingEnabled: false))
    }

    @Test("Explicit values win over the defaults")
    func explicitValuesWin() {
        let configuration = GameConfiguration(wordsPerPlayer: 4, roundDuration: 20, isSkippingEnabled: false)

        #expect(configuration.wordsPerPlayer == 4)
        #expect(configuration.roundDuration == 20)
        #expect(!configuration.isSkippingEnabled)
        #expect(!configuration.allowsDuplicateWords)
    }

    // MARK: - Team defaults
    @Test("A new team gets the first palette color no team uses yet")
    func defaultColorSkipsOccupied() {
        let palette = TeamDefaultColorGenerator.defaultColors
        let configuration = GameConfiguration(teams: [
            Team(name: "A", color: palette[0]),
            Team(name: "B", color: palette[1]),
        ])

        let color = TeamDefaultColorGenerator().generateDefaultColor(for: configuration)

        #expect(color.isApproximatelyEqual(to: palette[2]))
    }
}

// MARK: - Helpers
private extension GameManagerTests {
    func makeManager(words: [Word] = []) -> GameManager {
        GameManager(
            configuration: GameConfiguration(teams: Fixtures.teams(count: 2), words: words),
            store: store,
            sound: SoundSpy()
        )
    }
}
