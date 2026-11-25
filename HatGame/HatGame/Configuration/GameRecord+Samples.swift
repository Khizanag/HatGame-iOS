//
//  GameRecord+Samples.swift
//  HatGame
//

#if DEBUG
import Foundation

// MARK: - Sample games
/// Games for History in UI tests, snapshots, and the Testing Lab: a close
/// two-team game, a three-team game, one ended early, one online, and a tie
/// played nearby. Fixed ids and dates, so a snapshot never changes.
extension GameRecord {
    static func samples() -> [GameRecord] {
        [
            passAndPlay(
                number: 1,
                ended: "2026-11-24T21:40:00Z",
                minutes: 38,
                teams: [
                    SampleTeam(name: "Night Owls", color: sampleColors[0], players: ["Ann", "Ben", "Cleo"]),
                    SampleTeam(name: "Hat Tricks", color: sampleColors[1], players: ["Dan", "Eve", "Finn"]),
                ],
                pace: [6, 4, 5, 3, 7, 2]
            ),
            passAndPlay(
                number: 2,
                ended: "2026-11-21T20:05:00Z",
                minutes: 52,
                teams: [
                    SampleTeam(name: "Wordsmiths", color: sampleColors[2], players: ["Gia", "Hana"]),
                    SampleTeam(name: "Mimes", color: sampleColors[3], players: ["Ilia", "Jo"]),
                    SampleTeam(name: "Quiet Ones", color: sampleColors[4], players: ["Kat", "Levan"]),
                ],
                pace: [5, 3, 4, 6, 2, 5, 4]
            ),
            passAndPlay(
                number: 3,
                ended: "2026-11-14T19:30:00Z",
                minutes: 27,
                teams: [
                    SampleTeam(name: "Blue", color: sampleColors[0], players: ["Mari", "Nika"]),
                    SampleTeam(name: "Orange", color: sampleColors[1], players: ["Otar", "Pia"]),
                ],
                pace: [4, 4, 4, 4, 4, 4],
                skipped: 0
            ),
            passAndPlay(
                number: 4,
                ended: "2026-11-02T22:15:00Z",
                minutes: 14,
                teams: [
                    SampleTeam(name: "Foxes", color: sampleColors[5], players: ["Rati", "Sopo"]),
                    SampleTeam(name: "Bears", color: sampleColors[2], players: ["Tamo", "Uta"]),
                ],
                pace: [5, 3, 6, 4],
                lastRound: 2
            ),
            multiplayer(number: 5, mode: .online, ended: "2026-10-30T18:20:00Z", scores: [[9, 7, 8], [7, 9, 6]]),
            multiplayer(number: 6, mode: .nearby, ended: "2026-10-12T20:45:00Z", scores: [[8, 8, 8], [9, 7, 8]]),
        ]
    }
}

// MARK: - Building samples
private extension GameRecord {
    struct SampleTeam {
        let name: String
        let color: TeamColor
        let players: [String]
    }

    static let sampleColors = TeamDefaultColorGenerator.defaultColors.map(TeamColor.init)

    static let sampleWords = [
        "penguin", "lighthouse", "volcano", "umbrella", "orchestra", "compass", "glacier", "lantern",
        "pyramid", "telescope", "waterfall", "carousel", "hedgehog", "submarine", "avalanche", "bonfire",
        "cathedral", "dragonfly", "harbour", "marathon",
    ]

    static func sampleId(_ number: UInt8) -> UUID {
        UUID(uuid: (0x5A, 0x4D, 0x50, 0x4C, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, number))
    }

    static func date(_ text: String) -> Date {
        (try? Date(text, strategy: .iso8601)) ?? .now
    }

    /// Plays the sample words through three rounds (or `lastRound`): teams in
    /// turn, explainers rotating, each turn getting the next `pace` words.
    static func passAndPlay(
        number: UInt8,
        ended: String,
        minutes: Int,
        teams: [SampleTeam],
        pace: [Int],
        skipped: Int = 1,
        lastRound: Int = 3
    ) -> GameRecord {
        let ids = teams.indices.map { "sample-\(number)-\($0)" }
        var turns: [TurnResult] = []
        var scores = Array(repeating: [0, 0, 0], count: teams.count)
        var step = 0
        for round in 1 ... lastRound {
            var remaining = sampleWords[...]
            // A game ended early stops partway through its last round.
            let stopsEarly = round == lastRound && lastRound < 3
            while !remaining.isEmpty, !stopsEarly || remaining.count > 6 {
                let team = step % teams.count
                let turnNumber = step / teams.count
                let words = Array(remaining.prefix(pace[step % pace.count]))
                remaining = remaining.dropFirst(words.count)
                let skips = step.isMultiple(of: 3) ? skipped : 0
                let points = words.count - skips
                scores[team][round - 1] += points
                turns.append(TurnResult(
                    id: turns.count,
                    round: round,
                    teamId: ids[team],
                    explainer: teams[team].players[turnNumber % teams[team].players.count],
                    words: words,
                    skipped: skips,
                    points: points,
                    endReason: remaining.isEmpty ? .allWordsGuessed : step % 5 == 4 ? .gaveUp : .timeExpired,
                    secondsUsed: remaining.isEmpty ? 34 : 60
                ))
                step += 1
            }
        }
        let endedAt = date(ended)
        return GameRecord(
            id: sampleId(number),
            mode: .passAndPlay,
            outcome: lastRound == 3 ? .finished : .endedEarly,
            startedAt: endedAt.addingTimeInterval(TimeInterval(-minutes * 60)),
            endedAt: endedAt,
            roundsPlayed: lastRound,
            settings: Settings(
                roundDuration: 60,
                wordCount: sampleWords.count,
                isSkippingEnabled: true,
                skipPenalty: 1
            ),
            teams: teams.indices.map { index in
                TeamResult(
                    id: ids[index],
                    name: teams[index].name,
                    color: teams[index].color,
                    players: teams[index].players,
                    roundScores: scores[index]
                )
            },
            turns: turns,
            sourceKey: nil
        )
    }

    static func multiplayer(number: UInt8, mode: Mode, ended: String, scores: [[Int]]) -> GameRecord {
        GameRecord(
            id: sampleId(number),
            mode: mode,
            outcome: .finished,
            startedAt: nil,
            endedAt: date(ended),
            roundsPlayed: 3,
            settings: Settings(roundDuration: 45, wordCount: 32, isSkippingEnabled: false, skipPenalty: 0),
            teams: [
                TeamResult(
                    id: "a", name: "Tbilisi", color: sampleColors[3], players: ["Zura", "Ana"], roundScores: scores[0]
                ),
                TeamResult(
                    id: "b", name: "Batumi", color: sampleColors[0], players: ["Lika", "Gio"], roundScores: scores[1]
                ),
            ],
            turns: [],
            sourceKey: "sample-\(number)"
        )
    }
}

// MARK: - Test hook
@MainActor private var hasPreparedHistory = false

extension UITestConfiguration {
    /// Fills History as `-uiTestHistory` asks: `empty` clears it, `samples`
    /// replaces it with the sample games. The History screens default to
    /// the samples, so their snapshots and audits always have games to show.
    @MainActor
    static func prepareHistory() async {
        // Home runs this each time it appears; only the launch's first counts,
        // or returning from a game would wipe the game just recorded.
        guard !hasPreparedHistory else { return }
        hasPreparedHistory = true
        let isHistoryScreen = screen == "history" || screen == "recap"
        guard let mode = history ?? (isHistoryScreen ? "samples" : nil) else { return }
        let gameHistory = GameHistory.shared
        gameHistory.deleteAll()
        if mode == "samples" {
            GameRecord.samples().reversed().forEach(gameHistory.record)
        }
        await gameHistory.waitForPendingWrites()
    }
}
#endif
