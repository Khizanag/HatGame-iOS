//
//  LocalFlowView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

/// Top-level container for nearby (MultipeerConnectivity) play. Mirrors
/// `OnlineFlowView` but injects a `LocalRoomManager`/`LocalGameSyncManager`
/// pair so the same gameplay views work over MC instead of Firebase.
struct LocalFlowView: View {
    @Environment(Navigator.self) private var presentingNavigator

    @State private var navigator = Navigator()
    @State private var roomManager: LocalRoomManager
    @State private var gameSyncManager: LocalGameSyncManager

    init() {
        // Use the user's device name when available — anything more
        // specific lives in the room/player flow.
        let manager = LocalRoomManager(displayName: Platform.deviceDisplayName)
        _roomManager = State(initialValue: manager)
        _gameSyncManager = State(initialValue: LocalGameSyncManager(roomManager: manager))
    }

    var body: some View {
        NavigationStack(path: Bindable(navigator).navigationPath) {
            LocalMenuView()
                .navigationDestination(for: AnyPage.self) { page in
                    page.view()
                        .environment(roomManager as RoomManager)
                        .environment(gameSyncManager as GameSyncManager)
                        .environment(navigator)
                }
        }
        .environment(roomManager as RoomManager)
        .environment(gameSyncManager as GameSyncManager)
        .environment(navigator)
        .environment(roomManager) // local-specific access for browser screen
        .onReceive(navigator.pleaseDismissViewPublisher) { presentingNavigator.presentedPage = nil }
    }
}
