//
//  HistoryView.swift
//  HatGame
//

import DesignBook
import Navigation
import SwiftUI

/// Every game played on this device, newest first, under a short overview.
/// Opened from Home's toolbar; a game opens its recap.
struct HistoryView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(\.locale) private var locale

    @State private var pendingDeletion: GameRecord?
    @State private var isClearConfirmationPresented = false
    @State private var deletions = 0

    private let history = GameHistory.shared

    var body: some View {
        content
            .navigationTitle(localized("history.title"))
            .setDefaultStyle(titleDisplay: .large)
            .toolbar { historyToolbar }
            .task { await history.load() }
            .haptic(.warning, trigger: deletions)
            .confirmationDialog(
                localized("history.delete.title"),
                isPresented: isDeletionPresented,
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { record in
                Button(localized("history.delete"), role: .destructive) { delete(record) }
                    .accessibilityIdentifier("history.delete.confirm")
                Button(localized("common.buttons.cancel"), role: .cancel) {}
            } message: { _ in
                Text(localized("history.delete.message"))
            }
            .confirmationDialog(
                localized("history.clear.title"),
                isPresented: $isClearConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(localized("history.clear"), role: .destructive, action: clearHistory)
                Button(localized("common.buttons.cancel"), role: .cancel) {}
            } message: {
                Text(localized("history.delete.message"))
            }
            .accessibilityIdentifier("history.page")
    }
}

// MARK: - Composition
private extension HistoryView {
    @ViewBuilder
    var content: some View {
        if !history.isLoaded {
            Color.clear
        } else if history.records.isEmpty {
            emptyState
        } else {
            list
        }
    }

    var list: some View {
        List {
            Section {
                HistoryOverview(records: history.records)
            } header: {
                Text(localized("history.overview"))
            }
            ForEach(monthGroups, id: \.start) { group in
                Section {
                    ForEach(group.records) { record in
                        HistoryRow(record: record) { open(record) }
                            .gameRecordActions(
                                record,
                                locale: locale,
                                onOpen: { open(record) },
                                onDelete: { pendingDeletion = record }
                            )
                    }
                } header: {
                    Text(group.start.formatted(.dateTime.month(.wide).year().locale(locale)))
                }
            }
        }
        .groupedListStyle()
        .scrollContentBackground(.hidden)
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label(localized("history.empty.title"), systemImage: "clock.arrow.circlepath")
        } description: {
            Text(localized("history.empty.message"))
        } actions: {
            SecondaryButton(title: localized("history.empty.action"), icon: "person.2.fill", action: startGame)
                .paddingHorizontalDefault()
        }
    }

    @ToolbarContentBuilder
    var historyToolbar: some ToolbarContent {
        if !history.records.isEmpty {
            ToolbarItem(placement: .trailingAction) {
                Button {
                    isClearConfirmationPresented = true
                } label: {
                    Label(localized("history.clear"), systemImage: "trash")
                }
                .help(localized("history.clear"))
                .accessibilityIdentifier("history.clear")
            }
        }
    }
}

// MARK: - Grouping
private extension HistoryView {
    struct MonthGroup {
        let start: Date
        let records: [GameRecord]
    }

    /// Games by the month they ended in, newest month first.
    var monthGroups: [MonthGroup] {
        let calendar = Calendar.current
        var groups: [MonthGroup] = []
        for record in history.records {
            let start = calendar.dateInterval(of: .month, for: record.endedAt)?.start ?? record.endedAt
            if let last = groups.last, last.start == start {
                groups[groups.count - 1] = MonthGroup(start: start, records: last.records + [record])
            } else {
                groups.append(MonthGroup(start: start, records: [record]))
            }
        }
        return groups
    }
}

// MARK: - Actions
private extension HistoryView {
    var isDeletionPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    func open(_ record: GameRecord) {
        navigator.push(.gameRecap(record.id))
    }

    func delete(_ record: GameRecord) {
        deletions += 1
        withAnimation(DesignBook.Motion.smooth) {
            history.delete(record.id)
        }
    }

    func clearHistory() {
        deletions += 1
        history.deleteAll()
    }

    /// Starts Pass and Play, unless a saved game is waiting: then Home,
    /// which offers to resume it before anything replaces it.
    func startGame() {
        Task {
            let saved = await FileGameStore.shared.load()
            if saved?.phase.isInProgress == true {
                navigator.popToRoot()
            } else {
                navigator.present(.teamSetup)
            }
        }
    }
}

// MARK: - Overview
/// How much has been played here: games, words guessed, and time at the table.
private struct HistoryOverview: View {
    let records: [GameRecord]

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        layout {
            figure(value: "\(records.count)", caption: localized("history.stat.games"))
            figure(value: "\(records.reduce(0) { $0 + $1.wordsGuessed })", caption: localized("history.stat.words"))
            figure(value: timePlayed, caption: localized("history.stat.time"))
        }
        .padding(.vertical, DesignBook.Spacing.xs)
    }
}

// MARK: - Overview parts
private extension HistoryOverview {
    var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignBook.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignBook.Spacing.md))
    }

    var timePlayed: String {
        let seconds = records.compactMap(\.duration).reduce(0, +)
        return GameRecord.durationText(seconds: Int(seconds.rounded()), locale: locale, width: .narrow)
    }

    func figure(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xxs) {
            Text(verbatim: value)
                .font(DesignBook.Font.title2)
                .monospacedDigit()
                .foregroundStyle(DesignBook.Color.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(DesignBook.Font.footnote)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
