//
//  WordCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import DesignBook
import SwiftUI

/// The hero word card during a turn. Got It and Skip are the buttons below
/// it; VoiceOver gets them as named actions on the card.
struct WordCard: View {
    let word: String
    let teamTint: Color
    let onGuessed: () -> Void
    let onSkip: () -> Void
    /// Whether skipping is currently allowed. Disabled when only the last word remains.
    let isSkipEnabled: Bool

    var body: some View {
        ZStack {
            cardBackground
            wordText
        }
        .frame(maxWidth: DesignBook.Size.wordCardMaxWidth)
        .aspectRatio(DesignBook.Size.wordCardAspectRatio, contentMode: .fit)
        // Scoring is never the default (double-tap) action: Got It and Skip
        // are named actions, so a stray double-tap can't score a word.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(localized("game.card.accessibility.word \(word)")))
        .accessibilityHint(Text(localized("game.card.accessibility.hint")))
        .accessibilityActions {
            Button(localized("game.gotIt"), action: onGuessed)
            if isSkipEnabled {
                Button(localized("game.skip"), action: onSkip)
            }
        }
    }
}

// MARK: - Subviews
private extension WordCard {
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: DesignBook.Size.heroCardCornerRadius, style: .continuous)
            .fill(DesignBook.Color.Background.card)
            .overlay {
                RoundedRectangle(cornerRadius: DesignBook.Size.heroCardCornerRadius, style: .continuous)
                    .fill(DesignBook.Gradient.brandBackdrop)
            }
            .shadow(.lifted(teamTint))
    }

    var wordText: some View {
        Text(word)
            .font(DesignBook.Font.displayLarge)
            .foregroundStyle(DesignBook.Color.Text.primary)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.4)
            .lineLimit(3)
            .padding(.horizontal, DesignBook.Spacing.lg)
            .contentTransition(.opacity)
    }
}

#Preview {
    WordCard(
        word: "ცხენი",
        teamTint: .blue,
        onGuessed: {},
        onSkip: {},
        isSkipEnabled: true
    )
    .padding()
    .background(DesignBook.Color.Background.primary)
}
