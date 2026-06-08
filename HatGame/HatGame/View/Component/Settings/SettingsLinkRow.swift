//
//  SettingsLinkRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 08.06.26.
//

import DesignBook
import SwiftUI

/// A tappable settings row that triggers navigation. Shows the colored icon
/// tile, a title, an optional trailing value, and a chevron. Fires a
/// selection haptic before running `action`.
struct SettingsLinkRow: View {
    let icon: String
    var tint: Color = DesignBook.Color.Text.accent
    let title: String
    var value: String?
    let action: () -> Void

    var body: some View {
        Button {
            DesignBook.Haptics.selection()
            action()
        } label: {
            HStack(spacing: DesignBook.Spacing.md) {
                SettingsIconTile(systemImage: icon, tint: tint)

                Text(title)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: DesignBook.Spacing.sm)

                if let value {
                    Text(value)
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.forward")
                    .font(DesignBook.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
