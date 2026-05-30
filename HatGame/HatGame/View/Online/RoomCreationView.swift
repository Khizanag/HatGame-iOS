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
    enum Field: Hashable { case name }

    @Environment(Navigator.self) private var navigator
    @Environment(RoomManager.self) private var roomManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("HatGame.lastPlayerName") private var playerName: String = ""
    @State private var wordsPerPlayer: Int = 5
    @State private var roundDuration: Int = 60
    @State private var isCreating: Bool = false
    @State private var error: Error?

    @FocusState private var focusedField: Field?

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool { !trimmedName.isEmpty && !isCreating }

    var body: some View {
        content
            .navigationTitle(String(localized: "createRoom.title"))
            .setDefaultStyle()
            .toolbar { keyboardToolbar }
            .alert("common.error", isPresented: errorBinding) {
                Button("common.gotIt") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
            .onAppear { focusedField = .name }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}

// MARK: - Composition
private extension RoomCreationView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                SetupHero(
                    systemImage: "wifi",
                    title: String(localized: "createRoom.hero.title"),
                    subtitle: String(localized: "createRoom.hero.subtitle")
                )
                nameCard
                settingsCard
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            if focusedField == nil {
                createButton
                    .paddingHorizontalDefault()
                    .padding(.top, DesignBook.Spacing.md)
                    .padding(.bottom, DesignBook.Spacing.sm)
                    .withFooterGradient()
            }
        }
    }

    var nameCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "person.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text("createRoom.yourName")
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
                TextField("createRoom.enterName", text: $playerName)
                    .textFieldStyle(.plain)
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .padding(DesignBook.Spacing.md)
                    .background(DesignBook.Color.Background.secondary)
                    .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.done)
                    .onSubmit(createRoom)
            }
        }
    }

    var settingsCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.lg) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "gearshape.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text("createRoom.gameSettings")
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                VStack(spacing: DesignBook.Spacing.md) {
                    GameSettingsRow(
                        icon: "text.bubble.fill",
                        title: String(localized: "createRoom.wordsPerPlayer"),
                        value: $wordsPerPlayer,
                        range: 3...10,
                        step: 1
                    )
                    GameSettingsRow(
                        icon: "timer",
                        title: String(localized: "createRoom.roundDuration"),
                        value: $roundDuration,
                        range: 30...120,
                        step: 10,
                        suffix: String(localized: "createRoom.seconds")
                    )
                }
            }
        }
    }

    var createButton: some View {
        Group {
            if isCreating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignBook.Color.Text.accent))
                    .scaleEffect(1.2)
                    .padding(.vertical, DesignBook.Spacing.md)
            } else {
                PrimaryButton(title: String(localized: "createRoom.create"), icon: "plus.circle.fill") {
                    createRoom()
                }
                .disabled(!canCreate)
                .opacity(canCreate ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
            }
        }
    }

    @ToolbarContentBuilder
    var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(action: createRoom) {
                Label(String(localized: "createRoom.create"), systemImage: "plus.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .fontWeight(.semibold)
            }
            .disabled(!canCreate)
        }
    }
}

// MARK: - Actions
private extension RoomCreationView {
    func createRoom() {
        guard canCreate else { return }
        DesignBook.Haptics.confirm()
        isCreating = true
        focusedField = nil
        let name = trimmedName

        Task {
            do {
                let settings = GameSettings(wordsPerPlayer: wordsPerPlayer, roundDuration: roundDuration)
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
    NavigationView { RoomCreationView() }
        .environment(Navigator())
}
