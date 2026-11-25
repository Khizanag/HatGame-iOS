//
//  HistoryTests.swift
//  HatGameTests
//

import Foundation
@testable import HatGame
import Testing

// MARK: - Turn log
@Suite("Turn log")
struct TurnLogTests {
    @Test("A turn that runs out of time is logged with who explained and how long it ran")
    func expiredTurnIsLogged() throws {
        var generator = SeededGenerator()
        var state = Fixtures.playing(roundDuration: 30)
        state = GameRules.guess(state, remaining: .seconds(20), using: &generator)
        state = GameRules.skip(state, using: &generator)
        state = GameRules.expire(state)

        let entry = try #require(state.turnLog.last)
        let team = try #require(state.currentTeam)
        #expect(state.turnLog.count == 1)
        #expect(entry.round == .first)
        #expect(entry.teamId == team.id)
        #expect(entry.explainerId == state.explainer(for: team)?.id)
        #expect(entry.guessedWordIds.count == 1)
        #expect(entry.skippedCount == 1)
        #expect(entry.endReason == .timeExpired)
        #expect(entry.secondsUsed == 30)
    }

    @Test("Emptying the hat logs the turn with the time it took")
    func emptyingTheHatIsLogged() throws {
        var generator = SeededGenerator()
        var state = Fixtures.playing(words: Fixtures.words(["solo"]), roundDuration: 60)
        state = GameRules.guess(state, remaining: .seconds(45), using: &generator)

        let entry = try #require(state.turnLog.last)
        #expect(entry.endReason == .allWordsGuessed)
        #expect(entry.secondsUsed == 15)
    }

    @Test("A save from before the turn log loads with an empty one")
    func oldSaveDecodesWithEmptyLog() throws {
        let state = Fixtures.playing()
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
        )
        object.removeValue(forKey: "turnLog")
        object.removeValue(forKey: "startedAt")

        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: object))

        #expect(decoded.turnLog.isEmpty)
        #expect(decoded.startedAt == nil)
    }
}

// MARK: - Engine recording
@MainActor
@Suite("Engine records games", .timeLimit(.minutes(1)))
struct EngineRecordingTests {
    private let recorder = RecorderSpy()
    private let startDate = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A finished game is recorded once, with every turn and the scores")
    func finishedGameIsRecorded() throws {
        let engine = makeEngine()
        while engine.phase != .finished {
            engine.beginTurn(explainerIndex: 0)
            while engine.phase == .playing {
                engine.guess()
            }
            engine.continueAfterTurn()
        }
        engine.rematch()

        let record = try #require(recorder.records.first)
        #expect(recorder.records.count == 1)
        #expect(record.outcome == .finished)
        #expect(record.mode == .passAndPlay)
        #expect(record.roundsPlayed == 3)
        #expect(record.startedAt == startDate)
        #expect(record.wordsGuessed == 9)
        #expect(record.teams.map(\.total).reduce(0, +) == 9)
        #expect(record.turns.allSatisfy { $0.explainer != nil })
    }

    @Test("Ending a game with points on the board records it as ended early")
    func abandonWithPointsIsRecorded() throws {
        let engine = makeEngine()
        engine.beginTurn(explainerIndex: 0)
        engine.guess()
        engine.giveUp()

        engine.abandon()

        let record = try #require(recorder.records.first)
        #expect(record.outcome == .endedEarly)
        #expect(record.roundsPlayed == 1)
        #expect(record.turns.count == 1)
        #expect(record.turns.first?.endReason == .gaveUp)
    }

    @Test("Ending a game before anyone scored records nothing")
    func abandonWithoutPointsIsNotRecorded() {
        let engine = makeEngine()
        engine.beginTurn(explainerIndex: 0)
        engine.giveUp()

        engine.abandon()

        #expect(recorder.records.isEmpty)
    }

    private func makeEngine() -> GameEngine {
        let setup = Fixtures.state()
        let engine = GameEngine(
            state: setup,
            clock: ManualClock(),
            generator: SeededGenerator(),
            store: RecordingGameStore(),
            sound: SoundSpy(),
            recorder: recorder,
            currentDate: { [startDate] in startDate }
        )
        engine.start(setup, startingTeamIndex: 0)
        return engine
    }
}

// MARK: - Insights
@Suite("Game record insights")
struct GameRecordInsightsTests {
    @Test("Teams rank by total; the winner leads by the margin over second place")
    func rankingAndMargin() {
        let record = Self.record(totals: [[3, 4, 5], [6, 2, 1], [1, 1, 1]])

        #expect(record.ranking.map(\.name) == ["T0", "T1", "T2"])
        #expect(record.winners.map(\.name) == ["T0"])
        #expect(record.winningMargin == 3)
        #expect(!record.isTie)
    }

    @Test("Teams sharing the top total tie and share first place")
    func tie() {
        let record = Self.record(totals: [[4, 4, 4], [6, 3, 3], [1, 0, 0]])

        #expect(record.isTie)
        #expect(record.winningMargin == nil)
        #expect(record.winners.count == 2)
        #expect(record.rank(of: record.teams[1]) == 1)
        #expect(record.rank(of: record.teams[2]) == 3)
    }

    @Test("The best turn is the one with the most words; the earliest wins a tie")
    func bestTurn() {
        let record = Self.record(totals: [[0, 0, 0], [0, 0, 0]], turns: [
            Self.turn(0, team: "t0", explainer: "Ann", words: 2),
            Self.turn(1, team: "t1", explainer: "Ben", words: 4),
            Self.turn(2, team: "t0", explainer: "Cleo", words: 4),
        ])

        #expect(record.bestTurn?.id == 1)
    }

    @Test("Explainers add up their turns, most words first")
    func explainers() {
        let record = Self.record(totals: [[0, 0, 0], [0, 0, 0]], turns: [
            Self.turn(0, team: "t0", explainer: "Ann", words: 2),
            Self.turn(1, team: "t1", explainer: "Ben", words: 3),
            Self.turn(2, team: "t0", explainer: "Ann", words: 4),
        ])

        #expect(record.explainers.map(\.name) == ["Ann", "Ben"])
        #expect(record.explainers.first?.words == 6)
        #expect(record.explainers.first?.turns == 2)
        #expect(record.bestExplainer?.name == "Ann")
        #expect(record.wordsGuessed == 9)
    }

    static func record(totals: [[Int]], turns: [GameRecord.TurnResult] = []) -> GameRecord {
        GameRecord(
            id: UUID(),
            mode: .passAndPlay,
            outcome: .finished,
            startedAt: nil,
            endedAt: .now,
            roundsPlayed: 3,
            settings: GameRecord.Settings(roundDuration: 60, wordCount: 10, isSkippingEnabled: true, skipPenalty: 1),
            teams: totals.enumerated().map { index, scores in
                GameRecord.TeamResult(
                    id: "t\(index)",
                    name: "T\(index)",
                    color: TeamColor(red: 0.2, green: 0.4, blue: 0.6),
                    players: ["Ann", "Ben", "Cleo"],
                    roundScores: scores
                )
            },
            turns: turns,
            sourceKey: nil
        )
    }

    static func turn(_ id: Int, team: String, explainer: String, words: Int) -> GameRecord.TurnResult {
        GameRecord.TurnResult(
            id: id,
            round: 1,
            teamId: team,
            explainer: explainer,
            words: (0..<words).map { "w\($0)" },
            skipped: 0,
            points: words,
            endReason: .timeExpired,
            secondsUsed: 60
        )
    }
}

// MARK: - History
@MainActor
@Suite("Game history", .timeLimit(.minutes(1)))
struct GameHistoryTests {
    @Test("Games are kept newest first and saved")
    func recordsNewestFirst() async {
        let store = InMemoryHistoryStore()
        let history = GameHistory(store: store)

        history.record(Self.record(endedAt: 100))
        history.record(Self.record(endedAt: 300))
        history.record(Self.record(endedAt: 200))
        await history.waitForPendingWrites()

        #expect(history.records.map(\.endedAt.timeIntervalSince1970) == [300, 200, 100])
        #expect(await store.stored == history.records)
        #expect(await store.loadCount == 1)
    }

    @Test("A multiplayer game shown twice is recorded once")
    func sourceKeyRecordsOnce() async {
        let history = GameHistory(store: InMemoryHistoryStore())

        history.record(Self.record(endedAt: 100, sourceKey: "online-room"))
        history.record(Self.record(endedAt: 200, sourceKey: "online-room"))
        await history.waitForPendingWrites()

        #expect(history.records.count == 1)
    }

    @Test("Past capacity, the oldest games leave first")
    func capacity() async {
        let history = GameHistory(store: InMemoryHistoryStore())

        for index in 0 ... GameHistory.capacity {
            history.record(Self.record(endedAt: TimeInterval(index)))
        }
        await history.waitForPendingWrites()

        #expect(history.records.count == GameHistory.capacity)
        #expect(history.records.last?.endedAt.timeIntervalSince1970 == 1)
    }

    @Test("Deleting one game, then clearing, reaches the store")
    func deleteAndClear() async {
        let first = Self.record(endedAt: 100)
        let second = Self.record(endedAt: 200)
        let store = InMemoryHistoryStore(stored: [second, first])
        let history = GameHistory(store: store)

        history.delete(first.id)
        await history.waitForPendingWrites()
        #expect(history.records == [second])
        #expect(await store.stored == [second])

        history.deleteAll()
        await history.waitForPendingWrites()
        #expect(history.records.isEmpty)
        #expect(await store.stored.isEmpty)
    }

    @Test("Loading reads what the store kept, without saving it back")
    func loadReadsStore() async {
        let store = InMemoryHistoryStore(stored: [Self.record(endedAt: 50)])
        let history = GameHistory(store: store)

        await history.load()
        await history.load()

        #expect(history.isLoaded)
        #expect(history.records.count == 1)
        #expect(await store.loadCount == 1)
        #expect(await store.saveCount == 0)
    }

    static func record(endedAt: TimeInterval, sourceKey: String? = nil) -> GameRecord {
        GameRecord(
            id: UUID(),
            mode: .online,
            outcome: .finished,
            startedAt: nil,
            endedAt: Date(timeIntervalSince1970: endedAt),
            roundsPlayed: 3,
            settings: GameRecord.Settings(roundDuration: 60, wordCount: 10, isSkippingEnabled: false, skipPenalty: 0),
            teams: [],
            turns: [],
            sourceKey: sourceKey
        )
    }
}

// MARK: - File store
@Suite("File history store")
final class FileHistoryStoreTests {
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: "FileHistoryStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("Nothing saved loads as an empty history")
    func emptyLoadsEmpty() async {
        #expect(await FileHistoryStore(directory: directory).load().isEmpty)
    }

    @Test("Saved games load back as they were")
    func roundTrip() async {
        let store = FileHistoryStore(directory: directory)
        let records = [GameRecordInsightsTests.record(totals: [[1, 2, 3], [3, 2, 1]])]

        await store.save(records)

        #expect(await store.load() == records)
    }

    @Test("A record that can't be read is dropped and the rest load")
    func unreadableRecordIsDropped() async throws {
        let store = FileHistoryStore(directory: directory)
        let good = GameRecordInsightsTests.record(totals: [[1, 0, 0]])
        await store.save([good])
        let fileURL = directory.appending(path: "history.json")
        var array = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [Any]
        )
        array.append(["id": "not a game"])
        try JSONSerialization.data(withJSONObject: array).write(to: fileURL)

        #expect(await store.load() == [good])
    }
}
