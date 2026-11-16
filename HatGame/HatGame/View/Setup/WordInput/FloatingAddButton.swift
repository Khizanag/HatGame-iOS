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
            Image(systemName: "plus.circle.fill")
                .font(DesignBook.IconFont.large)
                .frame(width: DesignBook.Size.floatingButtonSize, height: DesignBook.Size.floatingButtonSize)
                .decorativeHeroSizing()
        }
        .glassProminentButtonStyle()
        .disabled(isDisabled)
        .matchedGeometryEffect(id: "addButton", in: namespace)
        .accessibilityLabel(Text(localized("wordInput.addWord")))
        .help(localized("wordInput.addWord"))
        .accessibilityShowsLargeContentViewer()
    }
}
