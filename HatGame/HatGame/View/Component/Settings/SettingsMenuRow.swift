//
//  SettingsMenuRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 08.06.26.
//

import DesignBook
import SwiftUI

/// A settings row with a static leading label and a trailing `Menu` control.
/// Only the trailing pill — which shows the current selection's icon and value
/// — opens the menu; the supplied content is typically an inline `Picker`
/// whose options each carry an icon and an automatic checkmark.
struct SettingsMenuRow<MenuContent: View>: View {
    let icon: String
    var tint: Color = DesignBook.Color.Text.accent
    let title: String
    var valueSystemImage: String?
    let value: String
    @ViewBuilder let menu: () -> MenuContent

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
                titleLabel
                menuButton
            }
        } else {
            HStack(spacing: DesignBook.Spacing.md) {
                titleLabel
                    .lineLimit(1)
                Spacer(minLength: DesignBook.Spacing.sm)
                menuButton
            }
        }
    }
}

// MARK: - Subviews
private extension SettingsMenuRow {
    var titleLabel: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            SettingsIconTile(systemImage: icon, tint: tint)

            Text(title)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .accessibilityHidden(true)
        }
    }

    var menuButton: some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: DesignBook.Spacing.xs) {
                if let valueSystemImage {
                    Image(systemName: valueSystemImage)
                        .foregroundStyle(tint)
                }

                Text(value)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(DesignBook.Font.caption)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            .font(DesignBook.Font.callout)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.vertical, DesignBook.Spacing.xs)
            .background(.quaternary, in: Capsule())
            .contentShape(Capsule())
            .fixedSize()
        }
        .tint(DesignBook.Color.Text.primary)
        .accessibilityLabel(Text(verbatim: "\(title), \(value)"))
    }
}
