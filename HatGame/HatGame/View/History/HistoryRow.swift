//
//  HistoryRow.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// One game in History: the result, every team's total, and when and how it
/// was played. The whole row opens the game's recap.
struct HistoryRow: View {
    let record: GameRecord
    let action: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignBook.Spacing.md) {
                SettingsIconTile(systemImage: record.resultSymbol, tint: record.resultColor)
                details
                Spacer(minLength: 0)
                RowChevron()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(record.accessibilitySummary(locale: locale)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("history.row")
    }
}

// MARK: - Components
private extension HistoryRow {
    var details: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xxs) {
            Text(record.headline)
                .font(DesignBook.Font.headline)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .lineLimit(2)
            Text(record.scoreline)
                .font(DesignBook.Font.subheadline)
                .monospacedDigit()
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .lineLimit(2)
            metadata
        }
    }

    var metadata: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.xs) {
            Image(systemName: record.modeSymbol)
                .accessibilityHidden(true)
            Text([record.shortDateText(locale: locale), record.outcomeNote].compactMap { $0 }.joined(separator: " · "))
                .lineLimit(2)
        }
        .font(DesignBook.Font.footnote)
        .foregroundStyle(DesignBook.Color.Text.tertiary)
    }
}

// MARK: - Game actions
extension View {
    /// Everything a game in History offers beyond its tap, defined once for
    /// every list that shows one (constitution article 12): a long press that
    /// previews the recap's header, then Open and Share, then Delete apart and
    /// last; and a swipe with Delete. Delete always asks first, so it never
    /// takes the destructive role in a swipe.
    func gameRecordActions(
        _ record: GameRecord,
        locale: Locale,
        onOpen: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(GameRecordActionsModifier(record: record, locale: locale, onOpen: onOpen, onDelete: onDelete))
    }
}

private struct GameRecordActionsModifier: ViewModifier {
    let record: GameRecord
    let locale: Locale
    let onOpen: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(action: onDelete) {
                    Label(localized("history.delete"), systemImage: "trash")
                }
                .tint(DesignBook.Color.Status.errorFill)
            }
            .contextMenu {
                Button(action: onOpen) {
                    Label(localized("history.open"), systemImage: "doc.text.magnifyingglass")
                }
                ShareLink(item: record.shareText(locale: locale)) {
                    Label(localized("history.share"), systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(localized("history.delete"), systemImage: "trash")
                }
            } preview: {
                // Opaque and one fixed width, so the lift never shows a hole
                // or a band of the platter's grey.
                GameRecapHeader(record: record)
                    .environment(\.locale, locale)
                    .frame(width: DesignBook.Size.previewWidth)
                    .padding(DesignBook.Spacing.lg)
                    .background(DesignBook.Color.Background.primary)
            }
            .accessibilityActions {
                Button(localized("history.delete"), action: onDelete)
            }
    }
}
