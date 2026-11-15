//
//  OnlineFlowView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 01.02.26.
//

import Navigation
import Networking
import SwiftUI

struct OnlineFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var onlineNavigator = Navigator()
    @State private var roomManager = RoomManager()
    @State private var gameSyncManager = GameSyncManager()

    var body: some View {
        NavigationStack(path: Bindable(onlineNavigator).navigationPath) {
            OnlineMenuView()
                // This is the flow's own NavigationStack — the one place pages register.
                // swiftlint:disable:next no_navigation_destination
                .navigationDestination(for: AnyPage.self) { page in
                    page.view()
                        .environment(roomManager)
                        .environment(gameSyncManager)
                        .environment(onlineNavigator)
                }
        }
        .environment(roomManager)
        .environment(gameSyncManager)
        .environment(onlineNavigator)
        .onReceive(onlineNavigator.pleaseDismissViewPublisher) {
            dismiss()
        }
        // Dismissing the sheet leaves the room: the observer stops streaming,
        // and in the lobby the player (or the host's room) is removed.
        .onDisappear {
            Task { try? await roomManager.leaveRoom() }
        }
    }
}
