//
//  GameRecapComponents.swift
//  HatGame
//

import DesignBook
import SwiftUI

// MARK: - Turn row
/// One turn: who explained for which team, the words they got across, how
/// the turn ended, and the points it scored.
struct RecapTurnRow: View {
    let turn: GameRecord.TurnResult
    let team: GameRecord.TeamResult?

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.sm) {
            Circle()
                .fill(team?.color.color ?? DesignBook.Color.Text.tertiary)
                .frame(width: DesignBook.Size.dotRegular, height: DesignBook.Size.dotRegular)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignBook.Spacing.xxs) {
                Text(title)
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                Text(wordsText)
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(endingText, systemImage: endingSymbol)
                    .font(DesignBook.Font.footnote)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: pointsText)
                .font(DesignBook.Font.title3)
                .monospacedDigit()
                .foregroundStyle(DesignBook.Color.Text.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }
}

// MARK: - Words
private extension RecapTurnRow {
    var title: String {
        let name = team?.name ?? ""
        guard let explainer = turn.explainer else { return name }
        return localized("recap.turn.title \(name) \(explainer)")
    }

    var wordsText: String {
        turn.words.isEmpty
            ? localized("recap.turn.noWords")
            : turn.words.formatted(.list(type: .and).locale(locale))
    }

    /// How the turn ended, how long it ran, and what was skipped.
    var endingText: String {
        var parts = [reasonText]
        if let seconds = turn.secondsUsed, seconds > 0 {
            parts.append(GameRecord.durationText(seconds: seconds, locale: locale))
        }
        if turn.skipped > 0 {
            parts.append(localized("recap.turn.skipped \(turn.skipped)"))
        }
        return parts.joined(separator: " · ")
    }

    var reasonText: String {
        switch turn.endReason {
        case .timeExpired: localized("recap.turn.timeExpired")
        case .gaveUp: localized("recap.turn.gaveUp")
        case .allWordsGuessed: localized("recap.turn.emptiedHat")
        }
    }

    var endingSymbol: String {
        switch turn.endReason {
        case .timeExpired: "timer"
        case .gaveUp: "flag.fill"
        case .allWordsGuessed: "checkmark.seal.fill"
        }
    }

    /// Signed, so a turn that lost points reads as a loss: "+5", "−1", "0".
    var pointsText: String {
        turn.points > 0 ? "+\(turn.points)" : turn.points < 0 ? "−\(-turn.points)" : "0"
    }

    var accessibilityText: String {
        [title, localized("recap.points \(turn.points)"), wordsText, endingText].joined(separator: ", ")
    }
}

// MARK: - A team's players
/// A team and what each of its players explained over the game.
struct RecapTeamPlayersCard: View {
    let team: GameRecord.TeamResult
    let explainers: [GameRecord.ExplainerStats]

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Circle()
                        .fill(team.color.color)
                        .frame(width: DesignBook.Size.dotRegular, height: DesignBook.Size.dotRegular)
                        .accessibilityHidden(true)
                    Text(team.name)
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.teamText(for: team.color.color))
                }
                .accessibilityAddTraits(.isHeader)
                ForEach(team.players, id: \.self) { player in
                    LabeledContent(player) {
                        Text(detail(for: player))
                            .monospacedDigit()
                    }
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detail(for player: String) -> String {
        guard let stats = explainers.first(where: { $0.name == player }) else {
            return localized("recap.player.didNotExplain")
        }
        return "\(localized("recap.words.count \(stats.words)")) · \(localized("recap.turns.count \(stats.turns)"))"
    }
}
