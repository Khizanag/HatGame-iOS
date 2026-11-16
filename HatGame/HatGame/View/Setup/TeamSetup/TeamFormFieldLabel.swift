//
//  TeamFormFieldLabel.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// An icon + caption label above a team form field. A `Label`, so the
/// symbol takes the caption's font and scales with it.
struct TeamFormFieldLabel: View {
    let icon: String
    let title: String.LocalizationValue

    var body: some View {
        Label {
            Text(localized(title))
                .foregroundStyle(DesignBook.Color.Text.secondary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(DesignBook.Color.Text.accent)
        }
        .font(DesignBook.Font.subheadlineSemibold)
        .accessibilityAddTraits(.isHeader)
    }
}
