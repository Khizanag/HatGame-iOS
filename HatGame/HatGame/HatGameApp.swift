//
//  HatGameApp.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Navigation
import Networking
import SwiftUI

@main
struct HatGameApp: App {
    @State private var appConfiguration = AppConfiguration.shared
    @State private var roomManager = RoomManager()
    @State private var gameSyncManager = GameSyncManager()

    init() {
        Networking.configure()
    }

    var body: some Scene {
        WindowGroup {
            // Disambiguate from SwiftUI's deprecated NavigationView — this
            // is the Navigation package wrapper, which owns a Navigator and
            // routes AnyPage destinations + full-screen covers underneath.
            Navigation.NavigationView {
                HomeView()
            }
            .environment(roomManager)
            .environment(gameSyncManager)
            .preferredColorScheme(preferredColorScheme)
            // Locale drives formatters; string lookups switch via
            // `bundle: .appLanguage`, which re-renders views in place on change.
            .environment(\.locale, appConfiguration.locale)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        #if DEBUG
        if let override = UITestConfiguration.colorScheme {
            return override.colorScheme
        }
        #endif
        return appConfiguration.colorScheme.colorScheme
    }
}
