//
//  PlayerWordsCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The finished player's words in a card, still editable.
struct PlayerWordsCard: View {
    let playerWords: [String]
    let wordsPerPlayer: Int
    let onRemove: (Int) -> Void

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(String(format: localized("wordInput.wordsAddedProgress"), playerWords.count, wordsPerPlayer))
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                PlayerWordsList(playerWords: playerWords, onRemove: onRemove)
            }
        }
    }
}
