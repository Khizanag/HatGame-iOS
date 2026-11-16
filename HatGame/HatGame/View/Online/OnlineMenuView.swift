//
//  OnlineMenuView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct OnlineMenuView: View {
    @Environment(Navigator.self) private var navigator

    /// A build without a database URL cannot reach any room, so the entry
    /// point says so up front instead of failing four screens in.
    private var isOnlineAvailable: Bool { Networking.isConfigured }

    var body: some View {
        content
            .navigationTitle(localized("online.title"))
            .setDefaultStyle()
    }
}

// MARK: - Composition
private extension OnlineMenuView {
    var content: some View {
        CenteredScrollView {
            ConnectivityMenuHero(
                symbol: "globe.americas.fill",
                title: "online.hero.title",
                description: "online.description",
                animation: .pulse
            )
            .paddingHorizontalDefault()
        }
        .actionBar {
            Group {
                if isOnlineAvailable {
                    actionButtons
                } else {
                    unavailableNotice
                }
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.xl)
            .padding(.bottom, DesignBook.Spacing.lg)
        }
    }

    var unavailableNotice: some View {
        GameCard {
            HStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: "icloud.slash")
                    .font(DesignBook.IconFont.medium)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .accessibilityHidden(true)
                Text(localized("online.unavailable"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    var actionButtons: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            PrimaryButton(title: localized("online.createRoom"), icon: "plus.circle.fill") {
                DesignBook.Haptics.tap()
                navigator.push(.createRoom)
            }
            SecondaryButton(title: localized("online.joinRoom"), icon: "arrow.right.circle") {
                DesignBook.Haptics.tap()
                navigator.push(.joinRoom)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        OnlineMenuView()
    }
    .environment(Navigator())
}
