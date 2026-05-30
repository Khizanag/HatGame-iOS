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
    enum Field: Hashable { case name }

    @Environment(Navigator.self) private var navigator
    @Environment(LocalRoomManager.self) private var roomManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("HatGame.lastPlayerName") private var hostName: String = ""
    @State private var wordsPerPlayer: Int = 5
    @State private var roundDuration: Int = 60
    @State private var isCreating: Bool = false
    @State private var error: Error?

    @FocusState private var focusedField: Field?

    private var trimmedName: String {
        hostName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool { !trimmedName.isEmpty && !isCreating }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                hero
                nameCard
                settingsCard
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .navigationTitle(String(localized: "local.host.title"))
        .setDefaultStyle()
        .toolbar { keyboardToolbar }
        .safeAreaInset(edge: .bottom) {
            if focusedField == nil {
                hostButton
                    .paddingHorizontalDefault()
                    .padding(.top, DesignBook.Spacing.md)
                    .padding(.bottom, DesignBook.Spacing.sm)
                    .withFooterGradient()
            }
        }
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
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(DesignBook.Gradient.primary)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
            }
            .accessibilityHidden(true)
            Text("local.host.hero.title")
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
            Text(trimmedName.isEmpty
                ? String(localized: "local.host.hero.subtitle.empty")
                : String(format: String(localized: "local.host.hero.subtitle.named"), trimmedName))
                .font(DesignBook.Font.caption)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: trimmedName)
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
                TextField("createRoom.enterName", text: $hostName)
                    .textFieldStyle(.plain)
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .padding(DesignBook.Spacing.md)
                    .background(DesignBook.Color.Background.secondary)
                    .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.done)
                    .onSubmit(host)
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

    var hostButton: some View {
        Group {
            if isCreating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignBook.Color.Text.accent))
                    .scaleEffect(1.2)
                    .padding(.vertical, DesignBook.Spacing.md)
            } else {
                PrimaryButton(title: String(localized: "local.host.start"), icon: "antenna.radiowaves.left.and.right") {
                    host()
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
            Button(action: host) {
                Label(String(localized: "local.host.start"), systemImage: "antenna.radiowaves.left.and.right")
                    .labelStyle(.titleAndIcon)
                    .fontWeight(.semibold)
            }
            .disabled(!canCreate)
        }
    }

    func host() {
        guard canCreate else { return }
        DesignBook.Haptics.confirm()
        focusedField = nil
        isCreating = true
        let name = trimmedName
        let settings = GameSettings(wordsPerPlayer: wordsPerPlayer, roundDuration: roundDuration)
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
