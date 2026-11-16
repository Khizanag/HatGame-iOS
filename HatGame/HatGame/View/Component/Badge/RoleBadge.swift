//
//  RoleBadge.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import DesignBook
import SwiftUI

/// A small uppercase pill used to flag a player's role on a row —
/// host, you, etc. Variants share spacing/typography so multiple
/// badges on the same row sit visually side-by-side.
struct RoleBadge: View {
    enum Style {
        case host
        case you
        case noTeam

        var titleKey: String.LocalizationValue {
            switch self {
            case .host: "lobby.host"
            case .you: "onlineNextTeam.you"
            case .noTeam: "lobby.noTeam"
            }
        }

        var textColor: Color {
            switch self {
            case .host: DesignBook.Color.Text.accent
            case .you: DesignBook.Color.Text.primary
            case .noTeam: DesignBook.Color.Text.tertiary
            }
        }

        var backgroundColor: Color {
            switch self {
            case .host: DesignBook.Color.Text.accent.opacity(0.15)
            case .you: DesignBook.Color.Background.secondary
            case .noTeam: DesignBook.Color.Background.secondary.opacity(0.6)
            }
        }
    }

    let style: Style

    var body: some View {
        Text(localized(style.titleKey))
            .font(DesignBook.Font.caption1Semibold)
            .textCase(.uppercase)
            .tracking(1.0)
            .foregroundStyle(style.textColor)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.vertical, 3)
            .background { Capsule().fill(style.backgroundColor) }
    }
}

#Preview {
    HStack(spacing: 8) {
        RoleBadge(style: .host)
        RoleBadge(style: .you)
        RoleBadge(style: .noTeam)
    }
    .padding()
}
