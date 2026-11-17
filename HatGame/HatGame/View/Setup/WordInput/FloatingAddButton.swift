//
//  FloatingAddButton.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The keyboard-hugging add button shown while the word field is focused.
struct FloatingAddButton: View {
    let action: () -> Void
    let isDisabled: Bool
    let namespace: Namespace.ID

    var body: some View {
        Button(action: action) {
            // The glass is the circle; a circled glyph would draw a second ring.
            Image(systemName: "plus")
                .font(DesignBook.IconFont.large)
                .fontWeight(.semibold)
                .frame(width: DesignBook.Size.floatingButtonSize, height: DesignBook.Size.floatingButtonSize)
                .decorativeHeroSizing()
        }
        .glassProminentButtonStyle()
        .buttonBorderShape(.circle)
        .disabled(isDisabled)
        .glassMorphID("addButton", in: namespace)
        .accessibilityLabel(Text(localized("wordInput.addWord")))
        .help(localized("wordInput.addWord"))
        .accessibilityShowsLargeContentViewer()
    }
}
