//
//  EmptyStateCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.05.26.
//

import DesignBook
import SwiftUI

/// In-flow empty-state placeholder that keeps the card visual language of
/// the surrounding lobby/browser screens. For top-level "nothing here yet"
/// states prefer `ContentUnavailableView`; this one is for sections inside
/// a list.
struct EmptyStateCard: View {
    let symbol: String
    let title: LocalizedStringKey
    var caption: LocalizedStringKey?
    var animatesSymbol: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: symbol)
                    .font(DesignBook.IconFont.extraLarge)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .symbolEffect(
                        .variableColor.iterative.dimInactiveLayers,
                        options: .repeating,
                        isActive: animatesSymbol && !reduceMotion
                    )
                Text(title)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .multilineTextAlignment(.center)
                if let caption {
                    Text(caption)
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, DesignBook.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
    }
}
