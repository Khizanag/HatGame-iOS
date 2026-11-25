//
//  GameRecapScoreboard.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// Every team's points in each round and in total, best first. At
/// accessibility sizes the table becomes one row per team, its rounds in a
/// line under it, since five columns no longer fit.
struct GameRecapScoreboard: View {
    let record: GameRecord

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var roundColumn: CGFloat = 34
    @ScaledMetric(relativeTo: .title3) private var totalColumn: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var rankSize: CGFloat = 24

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedRows
        } else {
            GameCard {
                VStack(spacing: DesignBook.Spacing.sm) {
                    headerRow
                    Divider()
                    ForEach(record.ranking) { team in
                        tableRow(for: team)
                    }
                }
            }
        }
    }
}

// MARK: - Table
private extension GameRecapScoreboard {
    var headerRow: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Text(localized("recap.column.team"))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(GameRound.allCases, id: \.rawValue) { round in
                Image(systemName: round.symbol)
                    .frame(width: roundColumn)
                    .accessibilityLabel(Text(round.title))
            }
            Text(localized("recap.column.total"))
                .frame(width: totalColumn, alignment: .trailing)
        }
        .font(DesignBook.Font.footnote)
        .foregroundStyle(DesignBook.Color.Text.secondary)
        .accessibilityElement(children: .combine)
    }

    func tableRow(for team: GameRecord.TeamResult) -> some View {
        let isLeader = record.rank(of: team) == 1
        return HStack(spacing: DesignBook.Spacing.sm) {
            HStack(spacing: DesignBook.Spacing.sm) {
                rankMark(for: team)
                Text(team.name)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(GameRound.allCases, id: \.rawValue) { round in
                Text(verbatim: roundScore(team, round.rawValue))
                    .font(DesignBook.Font.body)
                    .monospacedDigit()
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .frame(width: roundColumn)
            }
            Text(verbatim: "\(team.total)")
                .font(DesignBook.Font.title3)
                .fontWeight(isLeader ? .bold : .regular)
                .monospacedDigit()
                .foregroundStyle(
                    isLeader ? DesignBook.Color.teamText(for: team.color.color) : DesignBook.Color.Text.primary
                )
                .frame(width: totalColumn, alignment: .trailing)
        }
        .padding(.vertical, DesignBook.Spacing.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel(for: team)))
    }

    /// The team's colour with its place on it: a crown for first.
    func rankMark(for team: GameRecord.TeamResult) -> some View {
        let rank = record.rank(of: team)
        return ZStack {
            Circle()
                .fill(DesignBook.Color.opaque(team.color.color))
                .frame(width: rankSize, height: rankSize)
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(DesignBook.Font.caption1Semibold)
            } else {
                Text(verbatim: "\(rank)")
                    .font(DesignBook.Font.caption1Semibold)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(DesignBook.Color.onAccent(for: team.color.color))
    }

    func roundScore(_ team: GameRecord.TeamResult, _ round: Int) -> String {
        round <= record.roundsPlayed ? "\(team.score(in: round))" : "–"
    }
}

// MARK: - Accessibility sizes
private extension GameRecapScoreboard {
    var stackedRows: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            ForEach(record.ranking) { team in
                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    TeamScoreRowView(
                        name: team.name,
                        color: team.color.color,
                        rank: record.rank(of: team),
                        score: team.total,
                        isWinner: record.rank(of: team) == 1
                    )
                    Text(roundsLine(for: team))
                        .font(DesignBook.Font.footnote)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .padding(.horizontal, DesignBook.Spacing.md)
                }
            }
        }
    }
}

// MARK: - Words
private extension GameRecapScoreboard {
    func roundsLine(for team: GameRecord.TeamResult) -> String {
        (1 ... record.roundsPlayed)
            .map { localized("recap.round.score \($0) \(team.score(in: $0))") }
            .joined(separator: " · ")
    }

    func accessibilityLabel(for team: GameRecord.TeamResult) -> String {
        let rank = record.rank(of: team)
        let place = localized("game.results.teamScore.accessibility \(team.name) \(rank) \(team.total)")
        return "\(place). \(roundsLine(for: team))"
    }
}
