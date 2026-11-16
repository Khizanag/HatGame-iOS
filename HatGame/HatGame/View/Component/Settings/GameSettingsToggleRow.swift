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
/// `GameSettingsRow`. `tint` colors the icon; the switch keeps the system
/// tint, since its color only means on or off (HIG toggles.md).
struct GameSettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var tint: Color = DesignBook.Color.Text.accent

    @ScaledMetric(relativeTo: .title3) private var iconWidth = DesignBook.Size.iconSize

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: icon)
                    .font(DesignBook.IconFont.small)
                    .foregroundStyle(tint)
                    .frame(width: iconWidth)

                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    Text(title)
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(DesignBook.Font.subheadline)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, DesignBook.Spacing.xs)
    }
}
