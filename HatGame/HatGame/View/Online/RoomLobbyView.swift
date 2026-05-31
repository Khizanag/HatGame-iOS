//
//  RoomLobbyView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct RoomLobbyView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(RoomManager.self) private var roomManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingTeamCreation: Bool = false
    @State private var showingLeaveConfirmation: Bool = false
    @State private var error: Error?

    private var room: GameRoom? { roomManager.room }
    private var isHost: Bool { roomManager.isHost }
    private var allTeams: [OnlineTeam] { room?.teams ?? [] }
    private var allPlayers: [OnlinePlayer] { room?.players ?? [] }

    /// Every team must have ≥ 2 players for the round to be playable.
    private var canStartGame: Bool {
        guard allTeams.count >= 2 else { return false }
        return allTeams.allSatisfy { team in
            allPlayers.filter { $0.teamId == team.id }.count >= 2
        }
    }

    var body: some View {
        content
            .navigationTitle(String(localized: "lobby.title"))
            .setDefaultStyle()
            .toolbar { leaveToolbar }
            .sheet(isPresented: $showingTeamCreation) {
                OnlineTeamCreationView()
            }
            .alert(String(localized: "lobby.leave.title"), isPresented: $showingLeaveConfirmation) {
                Button(String(localized: "common.buttons.cancel"), role: .cancel) { }
                Button(String(localized: "lobby.leave.confirm"), role: .destructive) {
                    leaveRoom()
                }
            } message: {
                Text(isHost ? "lobby.leave.hostMessage" : "lobby.leave.guestMessage")
            }
            .alert("common.error", isPresented: errorBinding) {
                Button("common.gotIt") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}

// MARK: - Composition
private extension RoomLobbyView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                roomCodeCard
                playersCard
                teamsSection
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            actionFooter
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.md)
                .padding(.bottom, DesignBook.Spacing.sm)
                .withFooterGradient()
        }
        // Key on stable composites — team color edits and player team
        // reassignments only change inner fields, not the array of IDs;
        // hashing in the relevant inner fields makes the animation actually
        // catch those mutations.
        .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: allTeams.map { "\($0.id):\($0.colorHex):\($0.playerIds.joined())" })
        .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: allPlayers.map { "\($0.id):\($0.teamId ?? "_")" })
    }

    @ToolbarContentBuilder
    var leaveToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingLeaveConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(DesignBook.Color.Text.primary)
            }
            .accessibilityLabel(Text("lobby.leave.title"))
        }
    }

    var roomCodeCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                Text("lobby.shareCode")
                    .font(DesignBook.Font.smallCaption)
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)

                Text(room?.id ?? "------")
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .kerning(8)
                    .accessibilityLabel(Text("lobby.shareCode"))

                GlassEffectContainer(spacing: DesignBook.Spacing.md) {
                    HStack(spacing: DesignBook.Spacing.md) {
                        if let code = room?.id {
                            Button {
                                DesignBook.Haptics.tap()
                                UIPasteboard.general.string = code
                            } label: {
                                Label("lobby.copyCode", systemImage: "doc.on.doc")
                                    .font(DesignBook.Font.caption)
                            }
                            .buttonStyle(.glass)

                            ShareLink(
                                item: String(format: String(localized: "lobby.shareMessage"), code),
                                preview: SharePreview(String(localized: "online.title"))
                            ) {
                                Label("lobby.share", systemImage: "square.and.arrow.up")
                                    .font(DesignBook.Font.caption)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    var playersCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "person.3.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text("lobby.players")
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                    Spacer()
                    Text(verbatim: "\(allPlayers.count)")
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .monospacedDigit()
                }

                ForEach(allPlayers, id: \.id) { player in
                    playerRow(player)
                }
            }
        }
    }

    func playerRow(_ player: OnlinePlayer) -> some View {
        HStack(spacing: DesignBook.Spacing.md) {
            Circle()
                .fill(teamColor(for: player.teamId))
                .frame(width: 12, height: 12)

            Text(player.name)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)

            if player.id == room?.hostId {
                RoleBadge(style: .host)
            }

            if player.id == roomManager.currentPlayerId {
                RoleBadge(style: .you)
            }

            Spacer()

            if player.teamId != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignBook.Color.Status.success)
            } else {
                Text("lobby.noTeam")
                    .font(DesignBook.Font.caption)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
        }
        .padding(.vertical, DesignBook.Spacing.xs)
    }

    func teamColor(for teamId: String?) -> Color {
        guard let teamId,
              let team = allTeams.first(where: { $0.id == teamId }) else {
            return DesignBook.Color.Text.tertiary
        }
        return Color(hex: team.colorHex) ?? DesignBook.Color.Text.accent
    }

    var teamsSection: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
            HStack {
                Text("lobby.teams")
                    .font(DesignBook.Font.captionBold)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                Spacer()
                if isHost {
                    Button {
                        DesignBook.Haptics.tap()
                        showingTeamCreation = true
                    } label: {
                        Label("lobby.addTeam", systemImage: "plus.circle.fill")
                            .font(DesignBook.Font.caption)
                            .foregroundStyle(DesignBook.Color.Text.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if allTeams.isEmpty {
                emptyTeamsCard
            } else {
                ForEach(allTeams, id: \.id) { team in
                    teamCard(team)
                }
            }
        }
    }

    var emptyTeamsCard: some View {
        EmptyStateCard(
            symbol: "person.2.slash",
            title: "lobby.noTeams",
            caption: isHost ? "lobby.noTeams.host" : nil
        )
    }

    func teamCard(_ team: OnlineTeam) -> some View {
        let players = allPlayers.filter { $0.teamId == team.id }
        let amIInTeam = roomManager.currentPlayer?.teamId == team.id
        let color = Color(hex: team.colorHex) ?? DesignBook.Color.Text.accent

        return GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack {
                    Circle().fill(color).frame(width: 14, height: 14)
                    Text(team.name)
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(color)
                    Spacer()
                    Text(verbatim: "\(players.count)")
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .monospacedDigit()
                        .padding(.horizontal, DesignBook.Spacing.sm)
                        .padding(.vertical, 2)
                        .background { Capsule().fill(color.opacity(0.15)) }
                }

                if players.isEmpty {
                    Text("lobby.teamEmpty")
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(players, id: \.id) { player in
                            HStack(spacing: DesignBook.Spacing.sm) {
                                Circle().fill(color.opacity(0.5)).frame(width: 6, height: 6)
                                Text(player.name)
                                    .font(DesignBook.Font.body)
                                    .foregroundStyle(DesignBook.Color.Text.secondary)
                            }
                        }
                    }
                }

                HStack(spacing: DesignBook.Spacing.md) {
                    if amIInTeam {
                        Button(action: { leaveTeam() }) {
                            Label("lobby.leaveTeam", systemImage: "arrow.uturn.left")
                                .font(DesignBook.Font.captionBold)
                        }
                        .buttonStyle(.glass)
                        .tint(DesignBook.Color.Status.error)
                    } else {
                        Button(action: { joinTeam(team.id) }) {
                            Label("lobby.joinTeam", systemImage: "person.crop.circle.fill.badge.plus")
                                .font(DesignBook.Font.captionBold)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(color)
                    }

                    Spacer()

                    if isHost {
                        Button(action: { removeTeam(team.id) }) {
                            Image(systemName: "trash")
                                .font(DesignBook.Font.body)
                                .foregroundStyle(DesignBook.Color.Status.error)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("teamCard.delete"))
                    }
                }
            }
        }
    }

    @ViewBuilder
    var actionFooter: some View {
        if isHost {
            VStack(spacing: DesignBook.Spacing.sm) {
                PrimaryButton(title: String(localized: "lobby.startGame"), icon: "play.fill") {
                    startGame()
                }
                .disabled(!canStartGame)
                .opacity(canStartGame ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)

                if !canStartGame {
                    Text("lobby.needMorePlayers")
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
        } else {
            HStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: "hourglass")
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.accent)
                    .symbolEffect(.pulse, options: .repeating)
                VStack(alignment: .leading, spacing: 2) {
                    Text("lobby.waitingForHost")
                        .font(DesignBook.Font.bodyBold)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    Text("lobby.waitingForHost.hint")
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
                Spacer()
            }
            .padding(DesignBook.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                    .fill(DesignBook.Color.Background.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                            .strokeBorder(DesignBook.Color.Text.accent.opacity(0.18), lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: - Actions
private extension RoomLobbyView {
    func joinTeam(_ teamId: String) {
        DesignBook.Haptics.selection()
        Task {
            do { try await roomManager.joinTeam(teamId: teamId) } catch { self.error = error }
        }
    }

    func leaveTeam() {
        DesignBook.Haptics.soft()
        Task {
            do { try await roomManager.leaveTeam() } catch { self.error = error }
        }
    }

    func removeTeam(_ teamId: String) {
        DesignBook.Haptics.rigid()
        Task {
            do { try await roomManager.removeTeam(teamId: teamId) } catch { self.error = error }
        }
    }

    func startGame() {
        DesignBook.Haptics.confirm()
        Task {
            do { try await roomManager.startGame() } catch { self.error = error }
        }
    }

    func leaveRoom() {
        Task {
            do {
                try await roomManager.leaveRoom()
                navigator.popToRoot()
            } catch {
                self.error = error
            }
        }
    }
}

#Preview {
    NavigationView { RoomLobbyView() }
        .environment(Navigator())
        .environment(RoomManager())
}
