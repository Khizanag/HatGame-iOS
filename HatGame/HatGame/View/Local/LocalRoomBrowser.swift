//
//  LocalRoomBrowser.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import DesignBook
@preconcurrency import MultipeerConnectivity
import Navigation
import Networking
import SwiftUI

/// Guest-side discovery screen — browses for nearby hosts advertising the
/// Hat Game multipeer service and lets the user pick one to join.
struct LocalRoomBrowser: View {
    enum Field: Hashable { case name }

    @Environment(Navigator.self) private var navigator
    @Environment(LocalRoomManager.self) private var roomManager

    @AppStorage("HatGame.lastPlayerName") private var playerName: String = ""
    @State private var isConnecting: Bool = false
    @State private var error: Error?

    @FocusState private var focusedField: Field?

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hosts: [LocalMultipeerService.DiscoveredHost] {
        roomManager.discoveredHosts
    }

    var body: some View {
        content
            .navigationTitle(String(localized: "local.browser.title"))
            .setDefaultStyle()
            .alert("common.error", isPresented: errorBinding) {
                Button("common.gotIt") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
            .onAppear {
                roomManager.startBrowsingForHosts()
                focusedField = .name
            }
            .onDisappear { roomManager.stopBrowsingForHosts() }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}

// MARK: - Composition
private extension LocalRoomBrowser {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                nameCard
                hostsSection
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
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
                    .onSubmit { focusedField = nil }
            }
        }
    }

    var hostsSection: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
            HStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(DesignBook.IconFont.medium)
                    .foregroundStyle(DesignBook.Color.Text.accent)
                    .symbolEffect(.pulse, options: .repeating)
                Text("local.browser.nearby")
                    .font(DesignBook.Font.captionBold)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                Spacer()
                Text(verbatim: "\(hosts.count)")
                    .font(DesignBook.Font.captionBold)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .monospacedDigit()
            }

            if hosts.isEmpty {
                emptyState
            } else {
                ForEach(hosts) { host in
                    hostRow(host)
                }
            }
        }
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label("local.browser.empty", systemImage: "antenna.radiowaves.left.and.right")
        } description: {
            Text("local.browser.empty.hint")
        }
    }

    func hostRow(_ host: LocalMultipeerService.DiscoveredHost) -> some View {
        Button {
            join(host)
        } label: {
            GameCard {
                HStack(spacing: DesignBook.Spacing.md) {
                    CircularIconContainer(
                        icon: "antenna.radiowaves.left.and.right",
                        size: 48,
                        iconSize: 22,
                        color: DesignBook.Color.Text.accent,
                        backgroundColor: DesignBook.Color.Text.accent.opacity(0.12)
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(host.discoveryInfo["host"] ?? host.displayName)
                            .font(DesignBook.Font.headline)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                            .lineLimit(1)
                        Text(host.displayName)
                            .font(DesignBook.Font.caption)
                            .foregroundStyle(DesignBook.Color.Text.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isConnecting {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(DesignBook.Font.title3)
                            .foregroundStyle(DesignBook.Color.Text.accent)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(trimmedName.isEmpty || isConnecting)
        .opacity(trimmedName.isEmpty ? DesignBook.Opacity.disabled : DesignBook.Opacity.enabled)
    }

    func join(_ host: LocalMultipeerService.DiscoveredHost) {
        guard !trimmedName.isEmpty else { return }
        DesignBook.Haptics.confirm()
        focusedField = nil
        isConnecting = true
        Task {
            do {
                try await roomManager.connectToHost(host, playerName: trimmedName)
                navigator.push(.localSession(roomCode: host.id.displayName))
            } catch {
                self.error = error
            }
            isConnecting = false
        }
    }
}
