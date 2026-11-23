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
            VStack(spacing: DesignBook.Spacing.xl) {
                ConnectivityMenuHero(
                    symbol: "globe.americas.fill",
                    title: "online.hero.title",
                    description: "online.description",
                    animation: .pulse
                )
                // What leaves the device, said where it starts (constitution article 26).
                Callout(tone: .info, systemImage: "lock", message: localized("online.privacy"))
            }
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
        Callout(tone: .warning, systemImage: "icloud.slash", message: localized("online.unavailable"))
    }

    var actionButtons: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            PrimaryButton(title: localized("online.createRoom"), icon: "plus.circle.fill") {
                navigator.push(.createRoom)
            }
            SecondaryButton(title: localized("online.joinRoom"), icon: "arrow.right.circle") {
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
