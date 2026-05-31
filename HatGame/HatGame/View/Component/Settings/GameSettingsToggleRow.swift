//
//  GameSettingsToggleRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 31.05.26.
//

import DesignBook
import SwiftUI

/// A labelled toggle row for boolean game settings (allow skipping, automatic
/// words). Shared by `RoomCreationView` and `LocalHostSetupView` so the two
/// host-setup flows look and behave the same — the toggle sibling of
/// `GameSettingsRow`.
struct GameSettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var tint: Color = DesignBook.Color.Text.accent

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: icon)
                    .font(DesignBook.IconFont.small)
                    .foregroundStyle(tint)
                    .frame(width: DesignBook.Size.iconSize)

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
        .padding(.vertical, DesignBook.Spacing.xs)
    }
}
