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

    @AppStorage(PlayerNameStorage.key) private var playerName: String = ""
    @State private var roomCode: String = ""
    @State private var isJoining: Bool = false
    @State private var error: Error?

    @FocusState private var focusedField: Field?

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canJoin: Bool {
        !trimmedName.isEmpty && RoomCode.isValid(roomCode) && !isJoining
    }

    var body: some View {
        content
            .navigationTitle(localized("joinRoom.title"))
            .setDefaultStyle()
            .errorAlert($error, title: localized("error.title.joinRoom"))
            .onAppear { focusedField = .code }
    }
}

// MARK: - Composition
private extension RoomJoinView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                SetupHero(
                    systemImage: "person.2.wave.2.fill",
                    title: localized("joinRoom.hero.title"),
                    subtitle: localized("joinRoom.hero.subtitle")
                )
                codeCard
                nameCard
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .actionBar {
            joinButton
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.md)
                .padding(.bottom, DesignBook.Spacing.sm)
        }
    }

    var codeCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "number")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text(localized("joinRoom.roomCode"))
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                TextField(localized("joinRoom.enterCode"), text: $roomCode)
                    .textFieldStyle(.plain)
                    .font(DesignBook.Font.scaled(32, relativeTo: .largeTitle, weight: .bold, design: .monospaced))
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .multilineTextAlignment(.center)
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
                    .autocapitalizeCharacters()
                    .padding(DesignBook.Spacing.md)
                    .background(DesignBook.Color.Background.secondary)
                    .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
                    .focused($focusedField, equals: .code)
                    .onChange(of: roomCode) { _, newValue in
                        let next = RoomCode.sanitized(newValue)
                        if next != roomCode { roomCode = next }
                        if RoomCode.isValid(next) {
                            focusedField = .name
                        }
                    }

                Text(localized("joinRoom.codeHint"))
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
        }
    }

    var nameCard: some View {
        PlayerNameCard(
            title: localized("joinRoom.yourName"),
            placeholder: localized("joinRoom.enterName"),
            name: $playerName,
            focus: $focusedField,
            field: .name,
            submitLabel: .join,
            onSubmit: joinRoom
        )
    }

    var joinButton: some View {
        Group {
            if isJoining {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignBook.Color.Text.accent))
                    .scaleEffect(1.2)
                    .padding(.vertical, DesignBook.Spacing.md)
            } else {
                PrimaryButton(title: localized("joinRoom.join"), icon: "arrow.right.circle.fill") {
                    joinRoom()
                }
                .disabled(!canJoin)
                .opacity(canJoin ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

// MARK: - Actions
private extension RoomJoinView {
    func joinRoom() {
        guard canJoin else { return }
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
    NavigationStack { RoomJoinView() }
        .environment(Navigator())
}
