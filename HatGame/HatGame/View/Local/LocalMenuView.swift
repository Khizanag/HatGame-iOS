//
//  LocalMenuView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import DesignBook
import Navigation
import SwiftUI

/// Entry screen for the nearby (MC) flow — mirrors `OnlineMenuView`.
struct LocalMenuView: View {
    @Environment(Navigator.self) private var navigator

    var body: some View {
        VStack(spacing: DesignBook.Spacing.xl) {
            Spacer()
            ConnectivityMenuHero(
                symbol: "dot.radiowaves.left.and.right",
                title: "local.hero.title",
                description: "local.description",
                animation: .iterating
            )
            Spacer()
            actions
        }
        .paddingHorizontalDefault()
        .padding(.bottom, DesignBook.Spacing.lg)
        .navigationTitle(localized("local.title"))
        .setDefaultStyle()
    }
}

// MARK: - Sub-views
private extension LocalMenuView {
    var actions: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            PrimaryButton(title: localized("local.host"), icon: "antenna.radiowaves.left.and.right") {
                DesignBook.Haptics.tap()
                navigator.push(.localHostSetup)
            }
            SecondaryButton(title: localized("local.join"), icon: "magnifyingglass") {
                DesignBook.Haptics.tap()
                navigator.push(.localBrowser)
            }
        }
    }
}
