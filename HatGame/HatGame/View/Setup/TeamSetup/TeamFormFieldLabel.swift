//
//  TeamFormFieldLabel.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// An icon + caption label above a team form field.
struct TeamFormFieldLabel: View {
    let icon: String
    let title: String.LocalizationValue

    var body: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignBook.IconFont.medium)
                .foregroundStyle(DesignBook.Color.Text.accent)

            Text(localized(title))
                .font(DesignBook.Font.subheadlineSemibold)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
    }
}
