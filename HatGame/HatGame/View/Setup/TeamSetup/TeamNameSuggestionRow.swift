//
//  TeamNameSuggestionRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// Inline row of tappable team-name suggestions with a shuffle button.
/// Appears below the team-name field when it's focused and empty.
struct TeamNameSuggestionRow: View {
    let suggestions: [String]
    let onPick: (String) -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            header

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        SuggestionChip(text: suggestion) {
                            onPick(suggestion)
                        }
                    }
                }
                .padding(.vertical, DesignBook.Spacing.xxs)
            }
            .scrollClipDisabled()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(localized("teamForm.suggestions.accessibility")))
    }
}

// MARK: - TeamNameSuggestionRow subviews
private extension TeamNameSuggestionRow {
    var header: some View {
        HStack(spacing: DesignBook.Spacing.xs) {
            Image(systemName: "wand.and.stars")
                .font(DesignBook.Font.caption1Semibold)
                .foregroundStyle(DesignBook.Color.Text.secondary)

            Text(localized("teamForm.suggestions.title"))
                .font(DesignBook.Font.caption1Semibold)
                .eyebrowUppercase()
                .tracking(1.2)
                .foregroundStyle(DesignBook.Color.Text.tertiary)

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "shuffle")
                    .font(DesignBook.Font.subheadlineSemibold)
            }
            .glassIconButtonStyle()
            .accessibilityLabel(Text(localized("teamForm.suggestions.shuffle")))
            .help(localized("teamForm.suggestions.shuffle"))
        }
    }
}

// MARK: - Suggestion chip
/// One tappable team-name suggestion.
struct SuggestionChip: View {
    let text: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(DesignBook.Font.subheadlineSemibold)
                .lineLimit(1)
        }
        .glassButtonStyle()
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .accessibilityLabel(Text(verbatim: text))
        .accessibilityHint(Text(localized("teamForm.suggestions.tap")))
    }
}
