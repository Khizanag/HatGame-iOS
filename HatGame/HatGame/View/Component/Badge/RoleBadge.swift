//
//  RoleBadge.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import DesignBook
import SwiftUI

/// A small uppercase pill that flags a player's role on a row: host, you,
/// explaining, guessing. The one way the app draws a role (constitution
/// article 30), so badges on one row sit side by side.
struct RoleBadge: View {
    enum Style {
        case host
        case you
        case noTeam
        /// The explainer, in their team's colour.
        case explaining(team: Color)
        case guessing

        var titleKey: String.LocalizationValue {
            switch self {
            case .host: "lobby.host"
            case .you: "onlineNextTeam.you"
            case .noTeam: "lobby.noTeam"
            case .explaining: "game.nextTeam.role.explaining"
            case .guessing: "game.nextTeam.role.guessing"
            }
        }

        var textColor: Color {
            switch self {
            case .host, .you: DesignBook.Color.Text.primary
            case .noTeam: DesignBook.Color.Text.tertiary
            case .explaining(let team): DesignBook.Color.teamText(for: team)
            case .guessing: DesignBook.Color.Text.secondary
            }
        }

        var backgroundColor: Color {
            switch self {
            case .host: DesignBook.Color.Text.primary.opacity(DesignBook.Opacity.light)
            case .you, .guessing: DesignBook.Color.Background.secondary
            case .noTeam: DesignBook.Color.Background.secondary.opacity(DesignBook.Opacity.semiTransparent)
            case .explaining(let team): team.opacity(DesignBook.Opacity.tint)
            }
        }
    }

    let style: Style

    var body: some View {
        Text(localized(style.titleKey))
            .font(DesignBook.Font.caption1Semibold)
            .eyebrowUppercase()
            .tracking(1.0)
            .foregroundStyle(style.textColor)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.vertical, DesignBook.Spacing.xxs)
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
