//
//  WordInputCompletionCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// Shown once a player has added all their words.
struct WordInputCompletionCard: View {
    let nextPlayerName: String?

    var body: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignBook.IconFont.extraLarge)
                    .foregroundStyle(DesignBook.Color.Status.success)

                Text(localized("wordInput.allWordsAdded"))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                if let nextPlayerName {
                    Text(String(format: localized("wordInput.readyToPass"), nextPlayerName))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(localized("wordInput.allPlayersEntered"))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DesignBook.Spacing.lg)
        }
    }
}
