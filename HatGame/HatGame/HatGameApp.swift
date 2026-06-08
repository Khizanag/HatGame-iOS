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
            #if os(macOS)
            // Portrait-first game UI: keep a phone-like default window with a
            // floor it can't be squished below; still freely resizable.
            .frame(minWidth: 460, idealWidth: 560, minHeight: 700, idealHeight: 880)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 560, height: 880)
        .windowResizability(.contentMinSize)
        .commands {
            // A party game has no documents; drop the default File ▸ New Window.
            CommandGroup(replacing: .newItem) { }
        }
        #endif

        #if os(macOS)
        // Native Settings window (Cmd-,). Reuses SettingsView inside its own
        // Navigator-owning stack so its sub-pages (defaults, app icon,
        // developer info, feedback) push within the Settings window.
        Settings {
            Navigation.NavigationView {
                SettingsView()
            }
            .environment(\.locale, appConfiguration.locale)
            .preferredColorScheme(preferredColorScheme)
            .frame(minWidth: 480, minHeight: 600)
        }
        #endif
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
