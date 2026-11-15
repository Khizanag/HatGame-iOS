//
//  CurrentAppIconCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import DesignBook
import SwiftUI

/// The settings card showing the app icon in use.
struct CurrentAppIconCard: View {
    let icon: AppIcon

    var body: some View {
        SettingsSection(
            title: localized("settings.appIcon.current"),
            footer: localized("settings.appIcon.current.description")
        ) {
            HStack(spacing: DesignBook.Spacing.md) {
                AppIconPreview(icon: icon, size: 60, symbolSize: 30)

                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    Text(icon.title)
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Text(icon.subtitle)
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                Spacer()
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .clipShape(.rect(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous))
        }
    }
}
