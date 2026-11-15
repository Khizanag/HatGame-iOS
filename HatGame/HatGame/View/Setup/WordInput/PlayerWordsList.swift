//
//  PlayerWordsList.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The current player's words, each removable.
struct PlayerWordsList: View {
    let playerWords: [String]
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            ForEach(playerWords.indices, id: \.self) { index in
                PlayerWordRow(
                    index: index,
                    text: playerWords[index],
                    onRemove: { onRemove(index) }
                )
                .id("word_\(index)")
                .transition(
                    .asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    )
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onRemove(index)
                    } label: {
                        Label(localized("common.buttons.delete"), systemImage: "trash.fill")
                    }
                }
            }
        }
    }
}

/// One numbered word with a remove button.
struct PlayerWordRow: View {
    let index: Int
    let text: String
    let onRemove: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var badgeSize: CGFloat = DesignBook.Size.badgeSize

    var body: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Text(verbatim: "\(index + 1)")
                .font(DesignBook.Font.caption)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
                .frame(width: badgeSize, height: badgeSize)
                .background(DesignBook.Color.Background.secondary)
                .clipShape(Circle())

            Text(text)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(DesignBook.IconFont.small)
                    .foregroundStyle(DesignBook.Color.Status.error.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(localized("wordInput.removeWord")))
        }
        .padding(DesignBook.Spacing.md)
        .background(DesignBook.Color.Background.secondary)
        .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
    }
}
