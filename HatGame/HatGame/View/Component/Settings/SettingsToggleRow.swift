//
//  SettingsToggleRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 08.06.26.
//

import DesignBook
import SwiftUI

/// A settings row wrapping a native `Toggle`, with the colored icon tile and
/// an optional subtitle. Fires a selection haptic when toggled.
struct SettingsToggleRow: View {
    let icon: String
    var tint: Color = DesignBook.Color.Text.accent
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: DesignBook.Spacing.md) {
                SettingsIconTile(systemImage: icon, tint: tint)

                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    Text(title)
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(DesignBook.Font.caption)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .tint(tint)
        .onChange(of: isOn) { _, _ in
            DesignBook.Haptics.selection()
        }
    }
}
