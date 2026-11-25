//
//  GameRecapView.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// One game from History: the result, the scoreboard by round, the
/// highlights, what each player explained, every turn, and the settings it
/// was played with. Multiplayer games keep scores only, so they stop after
/// the scoreboard. A page to read, on the opaque ground.
struct GameRecapView: View {
    let recordId: GameRecord.ID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var expandedRounds: Set<Int> = []
    @State private var isDeleteConfirmationPresented = false
    @State private var deletions = 0

    private let history = GameHistory.shared

    var body: some View {
        content
            .navigationTitle(localized("recap.title"))
            .setDefaultStyle()
            .toolbar { recapToolbar }
            .task { await history.load() }
            .haptic(.warning, trigger: deletions)
            .confirmationDialog(
                localized("history.delete.title"),
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(localized("history.delete"), role: .destructive, action: deleteGame)
                    .accessibilityIdentifier("history.delete.confirm")
                Button(localized("common.buttons.cancel"), role: .cancel) {}
            } message: {
                Text(localized("history.delete.message"))
            }
            .accessibilityIdentifier("recap.page")
    }
}

// MARK: - Composition
private extension GameRecapView {
    var record: GameRecord? { history.record(withId: recordId) }

    @ViewBuilder
    var content: some View {
        if let record {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignBook.Spacing.xxl) {
                    GameRecapHeader(record: record)
                    standingsSection(record)
                    if record.hasTurns {
                        highlightsSection(record)
                        playersSection(record)
                        turnsSection(record)
                    }
                    settingsSection(record)
                }
                .paddingHorizontalDefault()
                .padding(.vertical, DesignBook.Spacing.lg)
            }
        } else if history.isLoaded {
            ContentUnavailableView {
                Label(localized("recap.missing.title"), systemImage: "clock.arrow.circlepath")
            } description: {
                Text(localized("recap.missing.message"))
            }
        }
    }

    @ToolbarContentBuilder
    var recapToolbar: some ToolbarContent {
        if let record {
            ToolbarItem(placement: .trailingAction) {
                ShareLink(item: record.shareText(locale: locale)) {
                    Label(localized("history.share"), systemImage: "square.and.arrow.up")
                }
                .help(localized("history.share"))
            }
            ToolbarItem(placement: .trailingAction) {
                Button {
                    isDeleteConfirmationPresented = true
                } label: {
                    Label(localized("history.delete"), systemImage: "trash")
                }
                .help(localized("history.delete"))
                .accessibilityIdentifier("recap.delete")
            }
        }
    }

    func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
            Text(title)
                .font(DesignBook.Font.title2)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    func deleteGame() {
        deletions += 1
        history.delete(recordId)
        dismiss()
    }
}

// MARK: - Sections
private extension GameRecapView {
    func standingsSection(_ record: GameRecord) -> some View {
        section(localized(record.outcome == .finished ? "recap.standings.final" : "recap.standings")) {
            GameRecapScoreboard(record: record)
            if !record.hasTurns, record.mode != .passAndPlay {
                Callout(tone: .info, systemImage: "info.circle", message: localized("recap.multiplayerNote"))
            }
        }
    }

    func highlightsSection(_ record: GameRecord) -> some View {
        section(localized("recap.highlights")) {
            StatTileGrid(items: highlights(for: record)) { highlight in
                StatTile(
                    value: highlight.value,
                    caption: highlight.caption,
                    detail: highlight.detail,
                    accent: highlight.accent
                )
            }
        }
    }

    func playersSection(_ record: GameRecord) -> some View {
        section(localized("recap.players")) {
            VStack(spacing: DesignBook.Spacing.md) {
                ForEach(record.ranking) { team in
                    RecapTeamPlayersCard(team: team, explainers: record.explainers(on: team))
                }
            }
        }
    }

    func turnsSection(_ record: GameRecord) -> some View {
        section(localized("recap.turns")) {
            VStack(spacing: DesignBook.Spacing.md) {
                ForEach(GameRound.allCases.filter { $0.rawValue <= record.roundsPlayed }, id: \.rawValue) { round in
                    FoldableCard(
                        isExpanded: isExpanded(round.rawValue),
                        title: round.title,
                        description: turnsSummary(record.turns(in: round.rawValue)),
                        icon: round.symbol
                    ) {
                        VStack(spacing: DesignBook.Spacing.md) {
                            ForEach(record.turns(in: round.rawValue)) { turn in
                                RecapTurnRow(turn: turn, team: record.team(withId: turn.teamId))
                            }
                        }
                    }
                }
            }
        }
    }

    func settingsSection(_ record: GameRecord) -> some View {
        section(localized("recap.settings")) {
            GameCard {
                VStack(spacing: DesignBook.Spacing.sm) {
                    LabeledContent(localized("recap.settings.turnLength")) {
                        Text(GameRecord.durationText(seconds: record.settings.roundDuration, locale: locale))
                    }
                    Divider()
                    LabeledContent(localized("recap.settings.words")) {
                        Text(verbatim: "\(record.settings.wordCount)")
                    }
                    Divider()
                    LabeledContent(localized("recap.settings.skipping")) {
                        Text(skippingText(record.settings))
                    }
                }
                .font(DesignBook.Font.body)
                .monospacedDigit()
                .foregroundStyle(DesignBook.Color.Text.primary)
            }
        }
    }
}

// MARK: - Content
private extension GameRecapView {
    struct Highlight: Identifiable {
        let id: String
        let value: String
        let caption: String
        var detail: String?
        var accent: Color?
    }

    func highlights(for record: GameRecord) -> [Highlight] {
        var items: [Highlight] = []
        if let best = record.bestExplainer {
            let team = record.team(withId: best.teamId)
            let words = localized("recap.words.count \(best.words)")
            items.append(Highlight(
                id: "explainer",
                value: best.name,
                caption: localized("recap.bestExplainer"),
                detail: [words, team?.name].compactMap { $0 }.joined(separator: " · "),
                accent: team?.color.color
            ))
        }
        if let turn = record.bestTurn {
            let team = record.team(withId: turn.teamId)
            let who = [turn.explainer, team?.name].compactMap { $0 }.joined(separator: " · ")
            items.append(Highlight(
                id: "turn",
                value: localized("recap.words.count \(turn.words.count)"),
                caption: localized("recap.bestTurn"),
                detail: localized("recap.bestTurn.detail \(who) \(turn.round)"),
                accent: team?.color.color
            ))
        }
        items.append(Highlight(id: "words", value: "\(record.wordsGuessed)", caption: localized("recap.wordsGuessed")))
        items.append(
            record.settings.isSkippingEnabled
                ? Highlight(id: "skips", value: "\(record.skips)", caption: localized("recap.skips"))
                : Highlight(id: "turns", value: "\(record.turns.count)", caption: localized("recap.turnsPlayed"))
        )
        return items
    }

    func isExpanded(_ round: Int) -> Binding<Bool> {
        Binding(
            get: { expandedRounds.contains(round) },
            set: { isOpen in
                if isOpen {
                    expandedRounds.insert(round)
                } else {
                    expandedRounds.remove(round)
                }
            }
        )
    }

    func turnsSummary(_ turns: [GameRecord.TurnResult]) -> String {
        let words = turns.reduce(0) { $0 + $1.words.count }
        return "\(localized("recap.turns.count \(turns.count)")) · \(localized("recap.words.count \(words)"))"
    }

    func skippingText(_ settings: GameRecord.Settings) -> String {
        guard settings.isSkippingEnabled else { return localized("recap.settings.skipping.off") }
        return settings.skipPenalty == 0
            ? localized("recap.settings.skipping.free")
            : localized("recap.settings.skipping.penalty \(settings.skipPenalty)")
    }
}
