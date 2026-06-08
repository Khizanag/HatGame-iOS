//
//  OnlineMenuView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import SwiftUI

struct OnlineMenuView: View {
    @Environment(Navigator.self) private var navigator

    var body: some View {
        content
            .navigationTitle(localized("online.title"))
            .setDefaultStyle()
    }
}

// MARK: - Composition
private extension OnlineMenuView {
    var content: some View {
        VStack(spacing: DesignBook.Spacing.xl) {
            Spacer()
            ConnectivityMenuHero(
                symbol: "globe.americas.fill",
                title: "online.hero.title",
                description: "online.description",
                animation: .pulse
            )
            Spacer()
            actionButtons
        }
        .paddingHorizontalDefault()
        .padding(.bottom, DesignBook.Spacing.lg)
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
