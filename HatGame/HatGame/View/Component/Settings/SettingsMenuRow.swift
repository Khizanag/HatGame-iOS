//
//  SettingsMenuRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 08.06.26.
//

import DesignBook
import SwiftUI

/// A settings row whose trailing control is a native `Menu`. Tapping the row
/// reveals the supplied menu content — typically an inline `Picker`, which
/// renders each option with an automatic checkmark on the current value.
struct SettingsMenuRow<MenuContent: View>: View {
    let icon: String
    var tint: Color = DesignBook.Color.Text.accent
    let title: String
    let value: String
    @ViewBuilder let menu: () -> MenuContent

    var body: some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: DesignBook.Spacing.md) {
                SettingsIconTile(systemImage: icon, tint: tint)

                Text(title)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                Spacer(minLength: DesignBook.Spacing.sm)

                Text(value)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(DesignBook.Font.caption)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            .contentShape(.rect)
        }
        .tint(DesignBook.Color.Text.primary)
    }
}
