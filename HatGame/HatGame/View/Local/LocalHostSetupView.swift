//
//  LocalHostSetupView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

/// Host-side configuration screen for a nearby game — analogous to
/// `RoomCreationView` but the room is local-only so no codes are needed.
struct LocalHostSetupView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(LocalRoomManager.self) private var roomManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(PlayerNameStorage.key) private var hostName: String = ""
    @State private var settings = GameSettings()
    @State private var isCreating: Bool = false
    @State private var error: Error?

    private var trimmedName: String {
        hostName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        RoomSetupForm(
            playerName: $hostName,
            settings: $settings,
            actionTitle: localized("local.host.start"),
            actionIcon: "antenna.radiowaves.left.and.right",
            isWorking: isCreating,
            action: host
        ) {
            hero
        }
        .navigationTitle(localized("local.host.title"))
        .setDefaultStyle()
        .errorAlert($error, transport: .nearby)
        .onAppear {
            settings.isSkippingEnabled = AppConfiguration.shared.defaultSkippingEnabled
        }
    }
}

// MARK: - Subviews
private extension LocalHostSetupView {
    var hero: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(DesignBook.Gradient.primary)
                    .frame(width: 96, height: 96)
                    .blur(radius: 22)
                    .opacity(0.55)
                Circle()
                    .fill(DesignBook.Color.Background.card)
                    .frame(width: 84, height: 84)
                    .shadow(.medium)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(DesignBook.IconFont.sized(36, relativeTo: .largeTitle, weight: .bold))
                    .decorativeHeroSizing()
                    .foregroundStyle(DesignBook.Gradient.primary)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
            }
            .accessibilityHidden(true)
            Text(localized("local.host.hero.title"))
                .font(DesignBook.Font.title1)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
            Text(trimmedName.isEmpty
                ? localized("local.host.hero.subtitle.empty")
                : String(format: localized("local.host.hero.subtitle.named"), trimmedName))
                .font(DesignBook.Font.subheadline)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: trimmedName)
        }
    }

    func host() {
        guard !trimmedName.isEmpty, !isCreating else { return }
        isCreating = true
        let name = trimmedName
        let settings = settings
        Task {
            do {
                let roomId = try await roomManager.createRoom(hostName: name, settings: settings)
                navigator.push(.localSession(roomCode: roomId))
            } catch {
                self.error = error
            }
            isCreating = false
        }
    }
}
