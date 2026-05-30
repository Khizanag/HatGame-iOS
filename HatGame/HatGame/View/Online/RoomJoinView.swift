//
//  RoomJoinView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct RoomJoinView: View {
    enum Field: Hashable { case code, name }

    @Environment(Navigator.self) private var navigator
    @Environment(RoomManager.self) private var roomManager

    @AppStorage("HatGame.lastPlayerName") private var playerName: String = ""
    @State private var roomCode: String = ""
    @State private var isJoining: Bool = false
    @State private var error: Error?

    @FocusState private var focusedField: Field?

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canJoin: Bool {
        !trimmedName.isEmpty && roomCode.count == 6 && !isJoining
    }

    var body: some View {
        content
            .navigationTitle(String(localized: "joinRoom.title"))
            .setDefaultStyle()
            .toolbar { keyboardToolbar }
            .alert("common.error", isPresented: errorBinding) {
                Button("common.gotIt") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
            .onAppear { focusedField = .code }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}

// MARK: - Composition
private extension RoomJoinView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                SetupHero(
                    systemImage: "person.2.wave.2.fill",
                    title: String(localized: "joinRoom.hero.title"),
                    subtitle: String(localized: "joinRoom.hero.subtitle")
                )
                codeCard
                nameCard
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            if focusedField == nil {
                joinButton
                    .paddingHorizontalDefault()
                    .padding(.top, DesignBook.Spacing.md)
                    .padding(.bottom, DesignBook.Spacing.sm)
                    .withFooterGradient()
            }
        }
    }

    var codeCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "number")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text("joinRoom.roomCode")
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                TextField("joinRoom.enterCode", text: $roomCode)
                    .textFieldStyle(.plain)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .multilineTextAlignment(.center)
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(DesignBook.Spacing.md)
                    .background(DesignBook.Color.Background.secondary)
                    .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                    .focused($focusedField, equals: .code)
                    .onChange(of: roomCode) { _, newValue in
                        let filtered = newValue.uppercased()
                            .filter { $0.isLetter || $0.isNumber }
                            .prefix(6)
                        let next = String(filtered)
                        if next != roomCode { roomCode = next }
                        if next.count == 6 {
                            DesignBook.Haptics.selection()
                            focusedField = .name
                        }
                    }

                Text("joinRoom.codeHint")
                    .font(DesignBook.Font.caption)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
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
                    Text("joinRoom.yourName")
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
                TextField("joinRoom.enterName", text: $playerName)
                    .textFieldStyle(.plain)
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .padding(DesignBook.Spacing.md)
                    .background(DesignBook.Color.Background.secondary)
                    .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.join)
                    .onSubmit(joinRoom)
            }
        }
    }

    var joinButton: some View {
        Group {
            if isJoining {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignBook.Color.Text.accent))
                    .scaleEffect(1.2)
                    .padding(.vertical, DesignBook.Spacing.md)
            } else {
                PrimaryButton(title: String(localized: "joinRoom.join"), icon: "arrow.right.circle.fill") {
                    joinRoom()
                }
                .disabled(!canJoin)
                .opacity(canJoin ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
            }
        }
    }

    @ToolbarContentBuilder
    var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(action: joinRoom) {
                Label(String(localized: "joinRoom.join"), systemImage: "arrow.right.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .fontWeight(.semibold)
            }
            .disabled(!canJoin)
        }
    }
}

// MARK: - Actions
private extension RoomJoinView {
    func joinRoom() {
        guard canJoin else { return }
        DesignBook.Haptics.confirm()
        isJoining = true
        focusedField = nil
        let name = trimmedName
        let code = roomCode.uppercased()

        Task {
            do {
                try await roomManager.joinRoom(code: code, playerName: name)
                navigator.push(.roomLobby(roomCode: code))
            } catch {
                self.error = error
            }
            isJoining = false
        }
    }
}

#Preview {
    NavigationView { RoomJoinView() }
        .environment(Navigator())
}
