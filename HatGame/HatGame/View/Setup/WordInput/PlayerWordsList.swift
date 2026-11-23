//
//  PlayerWordsList.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The current player's words, each removable with its own button.
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
            }
        }
    }
}

/// One numbered word with a remove button.
struct PlayerWordRow: View {
    let index: Int
    let text: String
    let onRemove: () -> Void

    private var removeLabel: String {
        String(format: localized("wordInput.removeWord %@"), text)
    }

    var body: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            NumberBadge(number: index + 1)
                .accessibilityHidden(true)

            Text(text)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(DesignBook.IconFont.small)
                    .foregroundStyle(DesignBook.Color.Status.error.opacity(0.7))
                    .frame(minWidth: DesignBook.Size.touchTargetSize, minHeight: DesignBook.Size.touchTargetSize)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .pointerHoverEffect()
            .accessibilityLabel(Text(removeLabel))
            .help(removeLabel)
        }
        .padding(.leading, DesignBook.Spacing.md)
        .padding(.vertical, DesignBook.Spacing.xs)
        .background(DesignBook.Color.Background.secondary)
        .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
    }
}
