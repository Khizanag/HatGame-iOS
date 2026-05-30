//
//  GameManager.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Observation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.khizanag.hat-game", category: "GameManager")

@Observable
final class GameManager {
    // MARK: - Configuration
    var configuration: GameConfiguration

    // MARK: - History
    let historyManager = HistoryManager()

    // MARK: - Rounds
    private var roundIterator = GameConfiguration.rounds.makeIterator()
    var currentRound: GameRound?

    /// True once the round iterator has run out — the game is over and no more rounds will play.
    var isGameFinished: Bool { currentRound == nil }

    // MARK: - Words
    private var remainingWords: Set<Word> = []
    var remainingWordCount: Int { remainingWords.count }
    var currentWord: Word?

    // MARK: - Teams
    var currentTeam: Team { configuration.teams[currentTeamIndex] }
    private var currentTeamIndex: Int = 0

    // MARK: - Team Roles
    private var teamExplainerIndices: [UUID: Int] = [:]
    private var teamsWithLockedRoles: Set<UUID> = [] // Teams that have played at least once
    private var shouldRotateRoles: Bool = true

    // MARK: - Time Tracking
    private var teamRemainingTimes: [UUID: Int] = [:]

    // MARK: - Initialization
    init(configuration: GameConfiguration? = nil) {
        self.configuration = if let configuration {
            configuration
        } else if AppConfiguration.shared.isTestMode {
            .mockForTesting
        } else {
            GameConfiguration()
        }
    }

    // MARK: - Functions
    func start(startingTeamIndex: Int = 0) {
        currentTeamIndex = startingTeamIndex
        historyManager.setUp(configuration: configuration)
        historyManager.prepareForNewRound(.first)

        remainingWords = Set(configuration.words)
        currentRound = roundIterator.next()
        currentWord = remainingWords.randomElement()
    }

    func commitWordGuess() {
        guard let currentWord, let currentRound else {
            // Safety: this should never happen in normal flow, but prevents a crash.
            logger.warning("commitWordGuess called with no current word or round")
            return
        }

        historyManager.saveThatTeamGuessedWord(word: currentWord, for: currentTeam, round: currentRound)

        remainingWords.remove(currentWord)

        self.currentWord = remainingWords.randomElement()
    }

    /// Skip the current word without scoring it.
    /// The word stays in the hat for the next try; the next word is chosen randomly.
    /// No-op when skipping is disabled for this game, or if only one word remains
    /// (nothing to swap with).
    func skipCurrentWord() {
        guard configuration.isSkippingEnabled, let currentWord, remainingWords.count > 1 else { return }

        // Pick a different word so the player isn't handed the same one back.
        let candidates = remainingWords.subtracting([currentWord])
        if let next = candidates.randomElement() {
            self.currentWord = next
        }
    }

    func prepareForNewPlay() {
        // Rotate roles if needed (when time ran out, not when words completed early)
        if shouldRotateRoles {
            rotateExplainer(for: currentTeam)
        }

        if currentWord != nil { // Current round is not finished
            setNextTeam()
            currentWord = remainingWords.randomElement()
            shouldRotateRoles = true // Reset for next team
        } else { // Current round is finished
            setUpNextRound()
            shouldRotateRoles = true // Reset for next round
        }
    }

    func saveRemainingTime(_ seconds: Int, for team: Team) {
        teamRemainingTimes[team.id] = seconds
    }

    func getRemainingTime(for team: Team) -> Int? {
        teamRemainingTimes[team.id]
    }

    func clearRemainingTime(for team: Team) {
        teamRemainingTimes.removeValue(forKey: team.id)
    }

    func getAllUsedWords() -> Set<String> {
        Set(configuration.words.map { $0.text })
    }

    // MARK: - Role Management
    func setExplainer(playerIndex: Int, for team: Team) {
        teamExplainerIndices[team.id] = playerIndex
        // Lock roles for this team - they can never select again
        teamsWithLockedRoles.insert(team.id)
    }

    func getExplainerIndex(for team: Team) -> Int? {
        teamExplainerIndices[team.id]
    }

    /// Returns true if this is the team's first play and roles can be selected
    /// After the first play, roles are locked and auto-rotated only
    func canSelectRoles(for team: Team) -> Bool {
        !teamsWithLockedRoles.contains(team.id)
    }

    func getExplainer(for team: Team) -> Player? {
        guard let index = teamExplainerIndices[team.id],
              index < team.players.count else {
            return nil
        }
        return team.players[index]
    }

    func getGuessers(for team: Team) -> [Player] {
        guard let explainerIndex = teamExplainerIndices[team.id] else {
            return Array(team.players.dropFirst())
        }
        return team.players.enumerated()
            .filter { $0.offset != explainerIndex }
            .map { $0.element }
    }

    func rotateExplainer(for team: Team) {
        guard !team.players.isEmpty else { return }

        let currentIndex = teamExplainerIndices[team.id] ?? 0
        let nextIndex = (currentIndex + 1) % team.players.count
        teamExplainerIndices[team.id] = nextIndex
    }

    func markPlayEndedWithTimeRemaining() {
        shouldRotateRoles = false
    }

    func markPlayEndedWithTimeOut() {
        shouldRotateRoles = true
    }

    func resetForNewGame() {
        // Reset round iterator
        roundIterator = GameConfiguration.rounds.makeIterator()
        currentRound = nil
        currentWord = nil
        currentTeamIndex = 0

        // Clear game state but keep teams
        remainingWords = []
        teamExplainerIndices = [:]
        teamsWithLockedRoles = []
        teamRemainingTimes = [:]
        shouldRotateRoles = true

        // Clear words - they need to be re-entered
        configuration.words = []
    }
}

// MARK: - Setup
extension GameManager {
    func addWords(_ words: [String], by player: Player) {
        configuration.words.append(
            contentsOf: words.map {
                .init(text: $0)
            }
        )
    }

    /// Replaces the word list with `count` random words from the bundled database.
    /// Used by the automatic word-source flow, where players don't type words in.
    func fillRandomWords(count: Int) {
        configuration.words = WordDatabase.randomWords(count: count).map { Word(text: $0) }
    }

    func addTeam(_ team: Team) {
        configuration.teams.append(team)
    }

    func removeTeam(_ team: Team) {
        configuration.teams.removeAll { $0.id == team.id }
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

// MARK: - Scores
extension GameManager {
    func getScore(for team: Team, in round: GameRound) -> Int {
        guard let ranking = historyManager.rankingForRound(round) else {
            return 0
        }
        return ranking.first(where: { $0.0.id == team.id })?.1 ?? 0
    }

    func getTotalScore(for team: Team) -> Int {
        let ranking = historyManager.totalRanking()
        return ranking.first(where: { $0.0.id == team.id })?.1 ?? 0
    }

    func getSortedTeamsByRoundScore(for round: GameRound) -> [Team] {
        historyManager.rankingForRound(round)?.map { $0.0 } ?? []
    }

    func getSortedTeamsByTotalScore() -> [Team] {
        historyManager.totalRanking().map { $0.0 }
    }

    func getCompletedRounds() -> [GameRound] {
        guard let currentRound = currentRound else {
            return GameRound.allCases
        }
        return GameRound.allCases.filter { $0.rawValue < currentRound.rawValue }
    }

    func getStartedRounds() -> [GameRound] {
        guard let currentRound = currentRound else {
            return GameRound.allCases
        }
        return GameRound.allCases.filter { $0.rawValue <= currentRound.rawValue }
    }
}

// MARK: - Private
private extension GameManager {
    /// Advance to the next round, preserving the current team's leftover time so they
    /// don't get an unfair fresh-timer start, and resetting everyone else's time pool.
    func setUpNextRound() {
        // Preserve only the current team's leftover time (they finished the round early).
        let preserved = teamRemainingTimes[currentTeam.id]
        teamRemainingTimes.removeAll()
        if let preserved {
            teamRemainingTimes[currentTeam.id] = preserved
        }

        currentRound = roundIterator.next()

        if let currentRound {
            remainingWords = Set(configuration.words)
            historyManager.prepareForNewRound(currentRound)
            currentWord = remainingWords.randomElement()
        } else {
            finishGame()
        }
    }

    func setNextTeam() {
        currentTeamIndex = (currentTeamIndex + 1) % configuration.teams.count
    }

    /// Clean up state once the final round has been played.
    func finishGame() {
        remainingWords = []
        currentWord = nil
        teamRemainingTimes.removeAll()
    }
}
