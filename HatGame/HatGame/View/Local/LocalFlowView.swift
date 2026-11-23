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
    @Environment(\.dismiss) private var dismiss

    @State private var navigator = Navigator()
    @State private var roomManager: LocalRoomManager
    @State private var gameSyncManager: LocalGameSyncManager

    init() {
        // Nearby peers see this name. Without a special entitlement the
        // device name is just "iPhone", so the player's remembered name
        // goes first.
        let savedName = PlayerNameStorage.savedName
        let manager = LocalRoomManager(displayName: savedName.isEmpty ? Platform.deviceDisplayName : savedName)
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
        .controlTint()
        .environment(roomManager as RoomManager)
        .environment(gameSyncManager as GameSyncManager)
        .environment(navigator)
        .environment(roomManager) // local-specific access for browser screen
        .onReceive(navigator.pleaseDismissViewPublisher) { dismiss() }
        .onDisappear {
            Task { try? await roomManager.leaveRoom() }
        }
        #if DEBUG
        // Outside the flow's own navigator: the lab routes on the app's.
        .hatGameTestingLab()
        #endif
    }
}
