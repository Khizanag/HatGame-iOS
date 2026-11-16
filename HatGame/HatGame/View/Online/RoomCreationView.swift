//
//  RoomCreationView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct RoomCreationView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(RoomManager.self) private var roomManager

    @AppStorage(PlayerNameStorage.key) private var playerName: String = ""
    @State private var settings = GameSettings()
    @State private var isCreating: Bool = false
    @State private var error: Error?

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        RoomSetupForm(
            playerName: $playerName,
            settings: $settings,
            actionTitle: localized("createRoom.create"),
            actionIcon: "plus.circle.fill",
            isWorking: isCreating,
            action: createRoom
        ) {
            SetupHero(
                systemImage: "wifi",
                title: localized("createRoom.hero.title"),
                subtitle: localized("createRoom.hero.subtitle")
            )
        }
        .navigationTitle(localized("createRoom.title"))
        .setDefaultStyle()
        .errorAlert($error)
        .onAppear {
            settings.isSkippingEnabled = AppConfiguration.shared.defaultSkippingEnabled
        }
    }
}

// MARK: - Actions
private extension RoomCreationView {
    func createRoom() {
        guard !trimmedName.isEmpty, !isCreating else { return }
        isCreating = true
        let name = trimmedName
        let settings = settings

        Task {
            do {
                let code = try await roomManager.createRoom(hostName: name, settings: settings)
                navigator.push(.roomLobby(roomCode: code))
            } catch {
                self.error = error
            }
            isCreating = false
        }
    }
}

#Preview {
    NavigationStack { RoomCreationView() }
        .environment(Navigator())
        .environment(RoomManager())
}
