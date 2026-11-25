//
//  GameRecord+Display.swift
//  HatGame
//

import DesignBook
import SwiftUI

// MARK: - Words
extension GameRecord {
    /// "Alpha won", "A tie", or who led when the game was ended early.
    var headline: String {
        guard let first = ranking.first else { return localized("history.row.tie") }
        if isTie {
            return localized("history.row.tie")
        }
        return outcome == .finished
            ? localized("history.row.won \(first.name)")
            : localized("history.row.led \(first.name)")
    }

    /// Every team and its total, best first: "Alpha 24 · Beta 19".
    var scoreline: String {
        ranking.map { "\($0.name) \($0.total)" }.joined(separator: " · ")
    }

    var outcomeNote: String? {
        guard outcome == .endedEarly else { return nil }
        return localized("history.endedEarly.round \(roundsPlayed)")
    }

    var modeTitle: String {
        switch mode {
        case .passAndPlay: localized("home.localGame")
        case .nearby: localized("home.nearbyGame")
        case .online: localized("home.onlineGame")
        }
    }

    var modeSymbol: String {
        switch mode {
        case .passAndPlay: "person.2.fill"
        case .nearby: "dot.radiowaves.left.and.right"
        case .online: "globe"
        }
    }

    /// The glyph of the row's leading tile: a crown for a winner, an equals
    /// sign for a tie, a flag for a game ended early.
    var resultSymbol: String {
        if isTie { return "equal" }
        return outcome == .finished ? "crown.fill" : "flag.fill"
    }

    /// The winner's colour; neutral for a tie.
    var resultColor: Color {
        guard !isTie, let first = ranking.first else { return DesignBook.Color.Text.secondary }
        return first.color.color
    }
}

// MARK: - Dates and times
extension GameRecord {
    func dateText(locale: Locale) -> String {
        endedAt.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(locale)
        )
    }

    /// The day and time, short enough for a row: "24 Nov, 21:40".
    func shortDateText(locale: Locale) -> String {
        endedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(locale))
    }

    func durationText(locale: Locale) -> String? {
        duration.map { Self.durationText(seconds: Int($0.rounded()), locale: locale) }
    }

    /// "38 min", "1 hr, 5 min", or "45 sec" in the app's language.
    static func durationText(
        seconds: Int,
        locale: Locale,
        width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated
    ) -> String {
        let allowed: Set<Duration.UnitsFormatStyle.Unit> = seconds < 60 ? [.seconds] : [.hours, .minutes]
        return Duration.seconds(seconds).formatted(
            .units(allowed: allowed, width: width, maximumUnitCount: 2).locale(locale)
        )
    }

    /// When, how long, and how it was played, for one quiet line.
    func detailLine(locale: Locale) -> String {
        [dateText(locale: locale), durationText(locale: locale), modeTitle]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

// MARK: - Sharing
extension GameRecord {
    /// The standings as plain text for Messages or Notes.
    func shareText(locale: Locale) -> String {
        var lines = [
            localized("history.share.header \(localized("home.title")) \(dateText(locale: locale))"),
            headline,
        ]
        for team in ranking {
            lines.append(localized("history.share.line \(rank(of: team)) \(team.name) \(team.total)"))
        }
        if let outcomeNote {
            lines.append(outcomeNote)
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - VoiceOver
extension GameRecord {
    func accessibilitySummary(locale: Locale) -> String {
        [headline, scoreline, outcomeNote, modeTitle, dateText(locale: locale)]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
