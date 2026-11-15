//
//  WordsReadyCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// Confirms how many words are in the hat.
struct WordsReadyCard: View {
    let wordCount: Int

    var body: some View {
        GameCard {
            HStack(spacing: DesignBook.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignBook.Size.smallCardCornerRadius)
                        .fill(DesignBook.Color.Status.success.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark.circle.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Status.success)
                }

                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    Text(localized("randomization.wordsReady.title"))
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Text(localized("randomization.wordsReady.count \(wordCount)"))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                Spacer()
            }
            .padding(DesignBook.Spacing.md)
        }
    }
}
