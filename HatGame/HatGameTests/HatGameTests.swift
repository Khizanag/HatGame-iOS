//
//  HatGameTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 15.11.25.
//

@testable import HatGame
import SwiftUI
import Testing

@MainActor
struct HatGameTests {
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
    }

    // MARK: - Configurable skipping
    @Test func skippingDisabledKeepsCurrentWord() {
        let manager = makeManager(isSkippingEnabled: false)
        manager.start()

        let wordBeforeSkip = manager.currentWord
        manager.skipCurrentWord()

        #expect(manager.currentWord == wordBeforeSkip)
    }

    @Test func skippingEnabledSwapsCurrentWord() {
        let manager = makeManager(isSkippingEnabled: true)
        manager.start()

        let wordBeforeSkip = manager.currentWord
        manager.skipCurrentWord()

        // With more than one word remaining, skipping always hands back a different word.
        #expect(manager.currentWord != wordBeforeSkip)
    }

    // MARK: - Word database
    /// The curated Georgian word list ships as a bundled resource; verify it loads,
    /// is substantial, has no duplicates, and contains only Mkhedruli letters.
    @Test func wordDatabaseLoadsCuratedResource() {
        let words = WordDatabase.words
        #expect(words.count > 3000)
        #expect(Set(words).count == words.count)
        let isMkhedruli = words.allSatisfy { word in
            word.unicodeScalars.allSatisfy { (0x10D0...0x10F0).contains(Int($0.value)) }
        }
        #expect(isMkhedruli)
    }

    // MARK: - Automatic word source
    /// The automatic word source fills the hat with the requested number of
    /// distinct words drawn from the bundled database.
    @Test func fillRandomWordsPopulatesDistinctDatabaseWords() {
        let manager = makeManager(isSkippingEnabled: true)
        manager.fillRandomWords(count: 20)

        let texts = manager.configuration.words.map(\.text)
        #expect(texts.count == 20)
        #expect(Set(texts).count == 20)
        let database = Set(WordDatabase.words)
        #expect(texts.allSatisfy { database.contains($0) })
    }

    // MARK: - Editing a team
    /// Editing a team must replace it in place, not move it to the end of the list.
    @Test func updateTeamReplacesInPlacePreservingOrder() {
        let manager = makeManager(isSkippingEnabled: true)
        let secondId = UUID()
        manager.addTeam(Team(name: "Beta", players: [Player(name: "X", teamId: secondId)], color: .red))

        let original = manager.configuration.teams[0]
        let edited = Team(id: original.id, name: "Renamed", players: original.players, color: original.color)
        manager.updateTeam(edited)

        #expect(manager.configuration.teams.count == 2)
        #expect(manager.configuration.teams[0].id == original.id)
        #expect(manager.configuration.teams[0].name == "Renamed")
        #expect(manager.configuration.teams[1].name == "Beta")
    }

    // MARK: - Runtime language switch
    /// The in-app switcher resolves strings via `bundle: .appLanguage`, which
    /// tracks `AppConfiguration.language`. Verify changing the language flips
    /// the resolved value, then restore the original.
    @Test func appLanguageBundleSwitchesLocalizedStrings() {
        let config = AppConfiguration.shared
        let original = config.language

        config.language = .english
        let english = String(localized: "settings.feedback.title", bundle: .appLanguage)

        config.language = .georgian
        let georgian = String(localized: "settings.feedback.title", bundle: .appLanguage)

        config.language = original

        #expect(english == "Send Feedback")
        #expect(georgian == "უკუკავშირის გაგზავნა")
        #expect(english != georgian)
    }

    // MARK: - Regression: idempotent transitions
    /// Plan E1: a second `start()` (double-tap, or back-swipe re-running it)
    /// must not advance the round or wipe round-one scores.
    @Test func startTwiceStaysInRoundOne() {
        let manager = makeManager(isSkippingEnabled: true)
        manager.start()
        manager.commitWordGuess()
        let team = manager.currentTeam

        manager.start()

        #expect(manager.currentRound == .first)
        #expect(manager.getScore(for: team, in: .first) == 1)
    }

    /// Plan E1: re-running the turn hand-off (back-swipe from Next Team) must
    /// not skip a team or rotate the explainer twice.
    @Test func prepareForNewPlayIsIdempotent() {
        let manager = makeTwoTeamManager()
        manager.start()
        let firstTeam = manager.currentTeam
        manager.setExplainer(playerIndex: 0, for: firstTeam)
        manager.markPlayEndedWithTimeOut()

        manager.prepareForNewPlay()
        manager.prepareForNewPlay()

        #expect(manager.currentTeam.id != firstTeam.id)
        #expect(manager.getExplainerIndex(for: firstTeam) == 1)
    }

    /// Plan E2: Play Again must start from zero — no round 2/3 scores carried
    /// over from the previous game.
    @Test func rematchClearsPreviousGameScores() {
        let manager = makeManager(isSkippingEnabled: true)
        manager.start()
        let team = manager.currentTeam
        while manager.currentWord != nil {
            manager.commitWordGuess()
        }
        manager.markPlayEndedWithTimeRemaining()
        manager.prepareForNewPlay()
        manager.commitWordGuess()
        #expect(manager.getScore(for: team, in: .second) == 1)

        manager.resetForRematch()
        manager.start()

        #expect(manager.getScore(for: team, in: .second) == 0)
        #expect(manager.getTotalScore(for: team) == 0)
    }

    // MARK: - Helpers
    private func makeManager(isSkippingEnabled: Bool) -> GameManager {
        let teamId = UUID()
        let team = Team(
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
        return GameManager(configuration: configuration)
    }

    private func makeTwoTeamManager() -> GameManager {
        let alphaId = UUID()
        let betaId = UUID()
        let alpha = Team(
            id: alphaId,
            name: "Alpha",
            players: [Player(name: "Alice", teamId: alphaId), Player(name: "Bob", teamId: alphaId)],
            color: .blue
        )
        let beta = Team(
            id: betaId,
            name: "Beta",
            players: [Player(name: "Carol", teamId: betaId), Player(name: "Dan", teamId: betaId)],
            color: .red
        )
        let configuration = GameConfiguration(
            teams: [alpha, beta],
            words: [Word(text: "one"), Word(text: "two"), Word(text: "three")]
        )
        return GameManager(configuration: configuration)
    }
}
