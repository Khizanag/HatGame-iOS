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
    /// The last edit typed characters a code can't contain, which were dropped.
    @State private var droppedCharacters: Bool = false
    /// The cleaned value written back by `sanitizeCode`, so its own change
    /// callback doesn't count as a new keystroke.
    @State private var sanitizedWrite: String?
    @State private var isJoining: Bool = false
    @State private var error: Error?
    @State private var completedActions = 0

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
            .haptic(.success, trigger: completedActions)
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
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                    Text(localized("joinRoom.roomCode"))
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                TextField(localized("joinRoom.enterCode"), text: $roomCode)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: .code)
                    .hatFieldStyle(
                        label: localized("joinRoom.roomCode"),
                        font: DesignBook.Font.scaled(32, relativeTo: .largeTitle, weight: .bold, design: .monospaced),
                        submitLabel: .next,
                        keyboard: .asciiCapable,
                        disablesAutocorrection: true,
                        capitalization: .characters
                    ) { focusedField = .code }
                    .onSubmit { focusedField = .name }
                    .onChange(of: roomCode) { _, newValue in
                        sanitizeCode(newValue)
                    }

                if droppedCharacters {
                    Label(localized("joinRoom.codeCharactersHint"), systemImage: "exclamationmark.circle")
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Status.warning)
                        .accessibilityIdentifier("joinRoom.codeCharactersHint")
                } else {
                    Text(localized("joinRoom.codeHint"))
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                }
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
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                    .padding(.vertical, DesignBook.Spacing.md)
            } else {
                PrimaryButton(title: localized("joinRoom.join"), icon: "arrow.right.circle.fill") {
                    joinRoom()
                }
                .disabled(!canJoin)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

// MARK: - Actions
private extension RoomJoinView {
    /// Keeps only code characters. When typed characters are dropped (a
    /// look-alike such as O or 1, punctuation, another script) the field
    /// says why instead of silently ignoring the keystroke.
    func sanitizeCode(_ newValue: String) {
        if let sanitizedWrite, sanitizedWrite == newValue {
            self.sanitizedWrite = nil
            return
        }
        let next = RoomCode.sanitized(newValue)
        let invalidCount = newValue.uppercased().filter { !RoomCode.alphabet.contains($0) }.count
        let didDrop = invalidCount > 0
        if didDrop != droppedCharacters {
            droppedCharacters = didDrop
            if didDrop {
                AccessibilityNotification.Announcement(localized("joinRoom.codeCharactersHint")).post()
            }
        }
        if next != newValue {
            sanitizedWrite = next
            roomCode = next
        }
        if RoomCode.isValid(next) {
            focusedField = .name
        }
    }

    func joinRoom() {
        guard canJoin else { return }
        isJoining = true
        focusedField = nil
        let name = trimmedName
        let code = roomCode.uppercased()

        Task {
            do {
                try await roomManager.joinRoom(code: code, playerName: name)
                completedActions += 1
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
