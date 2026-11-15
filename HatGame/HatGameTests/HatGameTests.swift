//
//  HatGameTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 15.11.25.
//

@testable import HatGame
import SwiftUI
import Testing

/// Regressions for bugs found in the single-device game, driven through the
/// same `GameManager` façade the screens use.
@MainActor
@Suite("Single-device regressions")
struct HatGameTests {
    private let store = RecordingGameStore()

    // MARK: - Fresh words per game
    /// Regression: `mockForTesting` used to be a shared `static let`. Because
    /// `GameConfiguration` is a reference type, one game's words leaked into the
    /// next game played in test mode. Each access must now return a fresh value.
    @Test func mockConfigurationIsFreshOnEachAccess() {
        let first = GameConfiguration.mockForTesting
        first.words.append(Word(text: "leak"))

        let second = GameConfiguration.mockForTesting

        #expect(second.words.isEmpty)
        #expect(first !== second)
        #expect(second.teams.allSatisfy { team in team.players.allSatisfy { $0.teamId == team.id } })
    }

    // MARK: - Configurable skipping
    @Test func skippingDisabledKeepsCurrentWord() {
        let manager = makeManager(isSkippingEnabled: false)
        manager.startGame(startingTeamIndex: 0)
        manager.engine.beginTurn(explainerIndex: 0)

        let wordBeforeSkip = manager.engine.state.currentWord
        manager.engine.skip()

        #expect(manager.engine.state.currentWord == wordBeforeSkip)
    }

    @Test func skippingEnabledSwapsCurrentWord() {
        let manager = makeManager(isSkippingEnabled: true)
        manager.startGame(startingTeamIndex: 0)
        manager.engine.beginTurn(explainerIndex: 0)

        let wordBeforeSkip = manager.engine.state.currentWord
        manager.engine.skip()

        // With more than one word remaining, skipping always hands back a different word.
        #expect(manager.engine.state.currentWord != wordBeforeSkip)
    }

    // MARK: - Editing a team
    /// Editing a team must replace it in place, not move it to the end of the list.
    @Test func updateTeamReplacesInPlacePreservingOrder() {
        let manager = makeManager(isSkippingEnabled: true)
        let secondId = UUID()
        manager.addTeam(Team(name: "Beta", players: [Player(name: "X", teamId: secondId)], color: .red))

        let original = manager.configuration.teams[0]
        let edited = Team(id: original.id, name: "Renamed", players: original.players, teamColor: original.teamColor)
        manager.updateTeam(edited)

        #expect(manager.configuration.teams.count == 2)
        #expect(manager.configuration.teams[0].id == original.id)
        #expect(manager.configuration.teams[0].name == "Renamed")
        #expect(manager.configuration.teams[1].name == "Beta")
    }

    // MARK: - Regression: idempotent transitions
    /// A second start (a double tap on Start) must not advance the round or
    /// wipe round-one scores.
    @Test func startTwiceStaysInRoundOne() throws {
        let manager = makeManager(isSkippingEnabled: true)
        manager.startGame(startingTeamIndex: 0)
        manager.engine.beginTurn(explainerIndex: 0)
        manager.engine.guess()
        let team = try #require(manager.engine.state.currentTeam)

        manager.startGame(startingTeamIndex: 0)

        #expect(manager.engine.state.round == .first)
        #expect(manager.engine.scoreboard.score(for: team, in: .first) == 1)
    }

    /// Continuing past the turn results twice must not skip a team or rotate
    /// the explainer twice.
    @Test func continueAfterTurnTwiceAdvancesOnce() throws {
        let manager = makeTwoTeamManager()
        manager.startGame(startingTeamIndex: 0)
        let firstTeam = try #require(manager.engine.state.currentTeam)
        manager.engine.beginTurn(explainerIndex: 0)
        manager.engine.giveUp()

        manager.engine.continueAfterTurn()
        manager.engine.continueAfterTurn()

        #expect(manager.engine.state.currentTeamId != firstTeam.id)
        #expect(manager.engine.state.explainerIndex(for: firstTeam) == 1)
    }

    /// Play Again starts from zero: no scores carry over from the finished game.
    @Test func rematchClearsPreviousGameScores() throws {
        let manager = makeTwoTeamManager()
        manager.startGame(startingTeamIndex: 0)
        let team = try #require(manager.engine.state.currentTeam)
        while manager.engine.phase != .finished {
            manager.engine.beginTurn(explainerIndex: 0)
            while manager.engine.phase == .playing {
                manager.engine.guess()
            }
            manager.engine.continueAfterTurn()
        }
        #expect(manager.engine.scoreboard.score(for: team, in: .third) > 0)

        manager.rematch()
        manager.startGame(startingTeamIndex: 0)

        #expect(manager.engine.scoreboard.totalScore(for: team) == 0)
        #expect(manager.engine.state.round == .first)
    }

    /// Play Again is only offered on the final results; mid-game it changes nothing.
    @Test func rematchMidGameIsIgnored() throws {
        let manager = makeTwoTeamManager()
        manager.startGame(startingTeamIndex: 0)
        manager.engine.beginTurn(explainerIndex: 0)
        manager.engine.guess()
        let state = manager.engine.state

        manager.rematch()

        #expect(manager.engine.state == state)
    }
}

// MARK: - Helpers
private extension HatGameTests {
    func makeManager(isSkippingEnabled: Bool) -> GameManager {
        let teamId = UUID()
        let team = Team(
            id: teamId,
            name: "Alpha",
            players: [
                Player(name: "Alice", teamId: teamId),
                Player(name: "Bob", teamId: teamId),
            ],
            color: .blue
        )
        let configuration = GameConfiguration(
            isSkippingEnabled: isSkippingEnabled,
            teams: [team],
            words: [Word(text: "one"), Word(text: "two"), Word(text: "three")]
        )
        return GameManager(configuration: configuration, store: store, sound: SoundSpy())
    }

    func makeTwoTeamManager() -> GameManager {
        let configuration = GameConfiguration(teams: Fixtures.teams(count: 2), words: Fixtures.words())
        return GameManager(configuration: configuration, store: store, sound: SoundSpy())
    }
}
