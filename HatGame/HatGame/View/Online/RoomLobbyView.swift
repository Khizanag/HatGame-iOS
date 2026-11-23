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
    @Environment(RoomManager.self) private var roomManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Nearby rooms have no code to share and word their errors for a
    /// local connection.
    let transport: NetworkErrorMessage.Transport

    @State private var showingTeamCreation: Bool = false
    @State private var isUpdating: Bool = false
    @State private var teamPendingDeletion: OnlineTeam?
    @State private var error: Error?
    /// Names the lobby action that failed ("Couldn't Join Team").
    @State private var errorTitle: String = ""
    @State private var removals = 0
    @State private var teamChoices = 0
    @State private var codeCopies = 0
    @State private var isCodeCopied = false

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
            .haptic(.warning, trigger: removals)
            .haptic(.selection, trigger: teamChoices)
            .haptic(.success, trigger: codeCopies)
            // The copy glyph turns to a check for a moment, in its own frame.
            .task(id: codeCopies) {
                guard isCodeCopied, (try? await Task.sleep(for: .seconds(2))) != nil else { return }
                isCodeCopied = false
            }
            .sheet(isPresented: $showingTeamCreation) {
                OnlineTeamCreationView()
                    .environment(\.showsScreenBackground, false)
            }
            .confirmationDialog(
                deletionTitle,
                isPresented: isDeletionConfirmationPresented,
                titleVisibility: .visible,
                presenting: teamPendingDeletion
            ) { team in
                Button(localized("lobby.deleteTeam.confirm"), role: .destructive) {
                    removeTeam(team.id)
                }
                Button(localized("common.buttons.cancel"), role: .cancel) { }
            } message: { _ in
                Text(localized("lobby.deleteTeam.message"))
            }
            .errorAlert($error, title: errorTitle, transport: transport)
    }
}

// MARK: - Composition
private extension RoomLobbyView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                switch transport {
                case .online: roomCodeCard
                // A nearby room's id is internal; guests find the room by
                // browsing, so there is no code to share.
                case .nearby: nearbyDiscoveryCard
                }
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

    var roomCodeCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                Text(localized("lobby.shareCode"))
                    .font(DesignBook.Font.caption1Semibold)
                    .eyebrowUppercase()
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
                                isCodeCopied = true
                                codeCopies += 1
                            } label: {
                                Label {
                                    Text(localized("lobby.copyCode"))
                                } icon: {
                                    Image(systemName: isCodeCopied ? "checkmark" : "doc.on.doc")
                                        .contentTransition(.symbolEffect(.replace))
                                }
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

    var nearbyDiscoveryCard: some View {
        GameCard {
            Label {
                Text(localized("lobby.nearbyHint"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            } icon: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(DesignBook.Color.Text.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

    /// One line at standard sizes; at accessibility sizes the name gets
    /// its own line and the badges and status move below it, so none of
    /// them is squeezed into a letter-wide column.
    func playerRow(_ player: OnlinePlayer) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignBook.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DesignBook.Spacing.md))
        return layout {
            HStack(spacing: DesignBook.Spacing.md) {
                Circle()
                    .fill(teamColor(for: player.teamId))
                    .frame(width: 12, height: 12)
                Text(player.name)
                    .font(DesignBook.Font.body)
                    .foregroundStyle(memberNameColor(for: player, connected: DesignBook.Color.Text.primary))
            }
            HStack(spacing: DesignBook.Spacing.md) {
                if player.id == room?.hostId {
                    RoleBadge(style: .host)
                        .fixedSize()
                }
                if player.id == roomManager.currentPlayerId {
                    RoleBadge(style: .you)
                        .fixedSize()
                }
                Spacer(minLength: 0)
                playerStatus(player)
            }
        }
        .padding(.vertical, DesignBook.Spacing.xs)
    }

    @ViewBuilder
    func playerStatus(_ player: OnlinePlayer) -> some View {
        if !player.isConnected {
            awayStatus(for: player)
        } else if let teamId = player.teamId {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DesignBook.Color.Status.success)
                .accessibilityLabel(Text(inTeamLabel(for: teamId)))
        } else {
            Text(localized("lobby.noTeam"))
                .font(DesignBook.Font.subheadline)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
        }
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
            Button(role: .destructive) {
                removeAwayPlayer(player)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .frame(minWidth: DesignBook.Size.touchTargetSize, minHeight: DesignBook.Size.touchTargetSize)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: localized("lobby.removePlayer"), player.name))
            .help(String(format: localized("lobby.removePlayer"), player.name))
            .accessibilityIdentifier("lobby.removePlayer")
        }
    }

    func memberNameColor(for player: OnlinePlayer, connected: Color = DesignBook.Color.Text.secondary) -> Color {
        player.isConnected ? connected : DesignBook.Color.Text.tertiary
    }

    func inTeamLabel(for teamId: String) -> String {
        guard let team = allTeams.first(where: { $0.id == teamId }) else {
            return localized("lobby.inTeam.unnamed")
        }
        return String(format: localized("lobby.inTeam"), team.name)
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
                        Label(localized("lobby.addTeam"), systemImage: "plus")
                            .font(DesignBook.Font.subheadline)
                    }
                    .glassButtonStyle()
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
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
        .contextMenu {
            if isHost {
                deleteTeamButton(team, hasPlayers: !players.isEmpty)
            }
        }
        .accessibilityActions {
            if isHost {
                deleteTeamButton(team, hasPlayers: !players.isEmpty)
            }
        }
    }

    /// Deleting a team lives in its long press (constitution article 12),
    /// asking first when players would lose their team.
    func deleteTeamButton(_ team: OnlineTeam, hasPlayers: Bool) -> some View {
        Button(role: .destructive) {
            if hasPlayers {
                teamPendingDeletion = team
            } else {
                removeTeam(team.id)
            }
        } label: {
            Label(String(format: localized("lobby.deleteTeam"), team.name), systemImage: "trash")
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
                        .foregroundStyle(DesignBook.Color.Status.error)
                }
                .glassButtonStyle()
            } else {
                Button {
                    joinTeam(team.id)
                } label: {
                    Label(localized("lobby.joinTeam"), systemImage: "person.crop.circle.fill.badge.plus")
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.teamText(for: color))
                }
                .glassButtonStyle()
            }

            Spacer()
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

// MARK: - Team deletion
private extension RoomLobbyView {
    var isDeletionConfirmationPresented: Binding<Bool> {
        Binding(
            get: { teamPendingDeletion != nil },
            set: { isPresented in
                if !isPresented { teamPendingDeletion = nil }
            }
        )
    }

    var deletionTitle: String {
        String(format: localized("lobby.deleteTeam.title"), teamPendingDeletion?.name ?? "")
    }
}

// MARK: - Actions
private extension RoomLobbyView {
    func joinTeam(_ teamId: String) {
        teamChoices += 1
        perform(failureTitle: localized("error.title.joinTeam")) { try await roomManager.joinTeam(teamId: teamId) }
    }

    func leaveTeam() {
        teamChoices += 1
        perform(failureTitle: localized("error.title.leaveTeam")) { try await roomManager.leaveTeam() }
    }

    func removeAwayPlayer(_ player: OnlinePlayer) {
        removals += 1
        perform(failureTitle: localized("error.title.removePlayer")) {
            try await roomManager.removeAwayPlayer(player.id)
        }
    }

    func removeTeam(_ teamId: String) {
        removals += 1
        perform(failureTitle: localized("error.title.deleteTeam")) { try await roomManager.removeTeam(teamId: teamId) }
    }

    func startGame() {
        perform(failureTitle: localized("error.title.startGame")) { try await roomManager.startGame() }
    }

    /// One lobby write in flight at a time; a tap while one is pending is
    /// dropped rather than racing it. `failureTitle` names the action in
    /// the alert if it fails.
    func perform(failureTitle: String, _ write: @escaping () async throws -> Void) {
        guard !isUpdating else { return }
        isUpdating = true
        Task {
            do {
                try await write()
            } catch {
                errorTitle = failureTitle
                self.error = error
            }
            isUpdating = false
        }
    }
}

#Preview {
    NavigationStack { RoomLobbyView(transport: .online) }
        .environment(Navigator())
        .environment(RoomManager())
}
