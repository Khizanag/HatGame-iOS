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
    @State private var isUpdating: Bool = false
    @State private var error: Error?

    private var room: GameRoom? { roomManager.room }
    private var isHost: Bool { roomManager.isHost }
    private var allTeams: [OnlineTeam] { room?.teams ?? [] }
    private var allPlayers: [OnlinePlayer] { room?.players ?? [] }

    /// Every team must have ≥ 2 players for the round to be playable.
    private var canStartGame: Bool {
        room.map(RoomRules.canStartGame) ?? false
    }

    var body: some View {
        content
            .navigationTitle(localized("lobby.title"))
            .setDefaultStyle()
            .toolbar { leaveToolbar }
            .sheet(isPresented: $showingTeamCreation) {
                OnlineTeamCreationView()
            }
            .alert(localized("lobby.leave.title"), isPresented: $showingLeaveConfirmation) {
                Button(localized("common.buttons.cancel"), role: .cancel) { }
                Button(localized("lobby.leave.confirm"), role: .destructive) {
                    leaveRoom()
                }
            } message: {
                Text(isHost ? localized("lobby.leave.hostMessage") : localized("lobby.leave.guestMessage"))
            }
            .errorAlert($error)
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
        .actionBar {
            actionFooter
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.md)
                .padding(.bottom, DesignBook.Spacing.sm)
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
        ToolbarItem(placement: .trailingAction) {
            Button {
                showingLeaveConfirmation = true
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(Text(localized("lobby.leave.title")))
        }
    }

    var roomCodeCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                Text(localized("lobby.shareCode"))
                    .font(DesignBook.Font.caption1Semibold)
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)

                Text(room?.id ?? "------")
                    .font(DesignBook.Font.roomCode)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .kerning(8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel(Text(localized("lobby.shareCode")))
                    .accessibilityValue(Text(verbatim: room?.id ?? "").speechSpellsOutCharacters())

                GlassContainer(spacing: DesignBook.Spacing.md) {
                    HStack(spacing: DesignBook.Spacing.md) {
                        if let code = room?.id {
                            Button {
                                Platform.copyToClipboard(code)
                            } label: {
                                Label(localized("lobby.copyCode"), systemImage: "doc.on.doc")
                                    .font(DesignBook.Font.subheadline)
                            }
                            .glassButtonStyle()

                            ShareLink(
                                item: String(format: localized("lobby.shareMessage"), code),
                                preview: SharePreview(localized("online.title"))
                            ) {
                                Label(localized("lobby.share"), systemImage: "square.and.arrow.up")
                                    .font(DesignBook.Font.subheadline)
                            }
                            .glassButtonStyle()
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
                    Text(localized("lobby.players"))
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                    Spacer()
                    Text(verbatim: "\(allPlayers.count)")
                        .font(DesignBook.Font.subheadlineSemibold)
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
                .foregroundStyle(player.isConnected ? DesignBook.Color.Text.primary : DesignBook.Color.Text.tertiary)

            if player.id == room?.hostId {
                RoleBadge(style: .host)
            }

            if player.id == roomManager.currentPlayerId {
                RoleBadge(style: .you)
            }

            Spacer()

            if !player.isConnected {
                awayStatus(for: player)
            } else if player.teamId != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignBook.Color.Status.success)
            } else {
                Text(localized("lobby.noTeam"))
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
        }
        .padding(.vertical, DesignBook.Spacing.xs)
    }

    /// A player whose device dropped off. The host can clear them so the room
    /// stops counting them; everyone else just sees that they're gone.
    @ViewBuilder
    func awayStatus(for player: OnlinePlayer) -> some View {
        Label(localized("lobby.away"), systemImage: "wifi.slash")
            .font(DesignBook.Font.subheadline)
            .foregroundStyle(DesignBook.Color.Status.warning)
            .accessibilityIdentifier("lobby.away")
        if isHost {
            Button {
                removeAwayPlayer(player)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: localized("lobby.removePlayer"), player.name))
            .accessibilityIdentifier("lobby.removePlayer")
        }
    }

    func memberNameColor(for player: OnlinePlayer) -> Color {
        player.isConnected ? DesignBook.Color.Text.secondary : DesignBook.Color.Text.tertiary
    }

    func teamColor(for teamId: String?) -> Color {
        guard let teamId,
              let team = allTeams.first(where: { $0.id == teamId }) else {
            return DesignBook.Color.Text.tertiary
        }
        return team.color
    }

    var teamsSection: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
            HStack {
                Text(localized("lobby.teams"))
                    .font(DesignBook.Font.subheadlineSemibold)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                Spacer()
                if isHost {
                    Button {
                        showingTeamCreation = true
                    } label: {
                        Label(localized("lobby.addTeam"), systemImage: "plus.circle.fill")
                            .font(DesignBook.Font.subheadline)
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
            caption: isHost ? "lobby.noTeams.host" : "lobby.noTeams.guest"
        )
    }

    func teamCard(_ team: OnlineTeam) -> some View {
        let players = allPlayers.filter { $0.teamId == team.id }
        let amIInTeam = roomManager.currentPlayer?.teamId == team.id
        let color = team.color

        return GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack {
                    Circle().fill(color).frame(width: 14, height: 14)
                    Text(team.name)
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.teamText(for: color))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer()
                    Text(verbatim: "\(players.count)")
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .monospacedDigit()
                        .padding(.horizontal, DesignBook.Spacing.sm)
                        .padding(.vertical, 2)
                        .background { Capsule().fill(color.opacity(0.15)) }
                }

                if players.isEmpty {
                    Text(localized("lobby.teamEmpty"))
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(players, id: \.id) { player in
                            HStack(spacing: DesignBook.Spacing.sm) {
                                Circle().fill(color.opacity(0.5)).frame(width: 6, height: 6)
                                Text(player.name)
                                    .font(DesignBook.Font.body)
                                    .foregroundStyle(memberNameColor(for: player))
                            }
                        }
                    }
                }

                teamActions(team, amIInTeam: amIInTeam, color: color)
            }
        }
    }

    func teamActions(_ team: OnlineTeam, amIInTeam: Bool, color: Color) -> some View {
        HStack(spacing: DesignBook.Spacing.md) {
            if amIInTeam {
                Button {
                    leaveTeam()
                } label: {
                    Label(localized("lobby.leaveTeam"), systemImage: "arrow.uturn.left")
                        .font(DesignBook.Font.subheadlineSemibold)
                }
                .glassButtonStyle()
                .tint(DesignBook.Color.Status.error)
            } else {
                Button {
                    joinTeam(team.id)
                } label: {
                    Label(localized("lobby.joinTeam"), systemImage: "person.crop.circle.fill.badge.plus")
                        .font(DesignBook.Font.subheadlineSemibold)
                }
                .glassProminentButtonStyle()
                .tint(color)
            }

            Spacer()

            if isHost {
                Button {
                    removeTeam(team.id)
                } label: {
                    Image(systemName: "trash")
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Status.error)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(localized("teamCard.delete")))
            }
        }
    }

    @ViewBuilder
    var actionFooter: some View {
        if isHost {
            VStack(spacing: DesignBook.Spacing.sm) {
                PrimaryButton(title: localized("lobby.startGame"), icon: "play.fill") {
                    startGame()
                }
                .disabled(!canStartGame || isUpdating)
                .opacity(canStartGame ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)

                if !canStartGame {
                    Text(localized("lobby.needMorePlayers"))
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
        } else {
            HStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: "hourglass")
                    .font(DesignBook.Font.title1)
                    .foregroundStyle(DesignBook.Color.Text.accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("lobby.waitingForHost"))
                        .font(DesignBook.Font.bodySemibold)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                    Text(localized("lobby.waitingForHost.hint"))
                        .font(DesignBook.Font.subheadline)
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
        perform { try await roomManager.joinTeam(teamId: teamId) }
    }

    func leaveTeam() {
        perform { try await roomManager.leaveTeam() }
    }

    func removeAwayPlayer(_ player: OnlinePlayer) {
        DesignBook.Haptics.rigid()
        perform { try await roomManager.removeAwayPlayer(player.id) }
    }

    func removeTeam(_ teamId: String) {
        DesignBook.Haptics.rigid()
        perform { try await roomManager.removeTeam(teamId: teamId) }
    }

    func startGame() {
        DesignBook.Haptics.confirm()
        perform { try await roomManager.startGame() }
    }

    /// One lobby write in flight at a time; a tap while one is pending is
    /// dropped rather than racing it.
    func perform(_ write: @escaping () async throws -> Void) {
        guard !isUpdating else { return }
        isUpdating = true
        Task {
            do { try await write() } catch { self.error = error }
            isUpdating = false
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
    NavigationStack { RoomLobbyView() }
        .environment(Navigator())
        .environment(RoomManager())
}
