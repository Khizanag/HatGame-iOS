//
//  CurrentAppIconRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import DesignBook
import SwiftUI

/// The list row showing the app icon in use.
struct CurrentAppIconRow: View {
    let icon: AppIcon

    var body: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            AppIconPreview(icon: icon, size: 60)

            VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                Text(icon.title)
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                Text(icon.subtitle)
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, DesignBook.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
