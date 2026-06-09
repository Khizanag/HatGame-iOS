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
    }
}
