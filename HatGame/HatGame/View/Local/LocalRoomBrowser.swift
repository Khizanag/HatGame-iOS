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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(PlayerNameStorage.key) private var playerName: String = ""
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
            .navigationTitle(localized("local.browser.title"))
            .setDefaultStyle()
            .errorAlert($error, title: localized("error.title.joinRoom"), transport: .nearby)
            .onAppear {
                roomManager.startBrowsingForHosts()
                focusedField = .name
            }
            .onDisappear { roomManager.stopBrowsingForHosts() }
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
        PlayerNameCard(
            title: localized("createRoom.yourName"),
            placeholder: localized("createRoom.enterName"),
            name: $playerName,
            focus: $focusedField,
            field: .name,
            onSubmit: { focusedField = nil }
        )
    }

    var hostsSection: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
            HStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(DesignBook.IconFont.medium)
                    .foregroundStyle(DesignBook.Color.Text.accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                Text(localized("local.browser.nearby"))
                    .font(DesignBook.Font.subheadlineSemibold)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                Spacer()
                Text(verbatim: "\(hosts.count)")
                    .font(DesignBook.Font.subheadlineSemibold)
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
            Label(localized("local.browser.empty"), systemImage: "antenna.radiowaves.left.and.right")
        } description: {
            Text(localized("local.browser.empty.hint"))
        }
    }

    /// The host player's name from the advertisement, else the peer's name.
    func hostName(of host: LocalMultipeerService.DiscoveredHost) -> String {
        host.discoveryInfo["host"] ?? host.displayName
    }

    func hostRow(_ host: LocalMultipeerService.DiscoveredHost) -> some View {
        Button {
            join(host)
        } label: {
            HStack(spacing: DesignBook.Spacing.md) {
                CircularIconContainer(
                    icon: "antenna.radiowaves.left.and.right",
                    size: 48,
                    iconSize: 22,
                    color: DesignBook.Color.Text.accent,
                    backgroundColor: DesignBook.Color.Text.accent.opacity(0.12)
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(hostName(of: host))
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                        .lineLimit(1)
                    // The device's advertised name, when it adds anything.
                    if host.displayName != hostName(of: host) {
                        Text(host.displayName)
                            .font(DesignBook.Font.subheadline)
                            .foregroundStyle(DesignBook.Color.Text.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isConnecting {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(DesignBook.Font.title1)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                }
            }
        }
        .buttonStyle(.glassCard)
        .disabled(trimmedName.isEmpty || isConnecting)
    }

    func join(_ host: LocalMultipeerService.DiscoveredHost) {
        guard !trimmedName.isEmpty else { return }
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
