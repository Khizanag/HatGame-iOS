//
//  TeamFormView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.25.
//

import DesignBook
import SwiftUI

struct TeamFormView: View {
    enum Field: Hashable {
        case teamName
        case player(Int)
    }

    /// What the form held when it opened; closing after a change confirms first.
    private struct Snapshot {
        let name: String
        let players: [String]
        let color: Color
    }

    @Environment(GameManager.self) private var gameManager
    @Environment(\.dismiss) private var dismissSheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let team: Team?
    let onPrimaryAction: (Team) -> Void

    @State private var teamName: String = ""
    @State private var playerNames: [String] = []
    /// The id of the player in each seat, `nil` for a new seat; kept beside
    /// `playerNames` so removing a seat doesn't hand its words to a neighbour.
    @State private var playerIds: [Player.ID?] = []
    @State private var teamColor: Color = TeamDefaultColorGenerator.defaultColors[0]
    @State private var nameSuggestions: [String] = TeamNameSuggestions.random()
    /// True once the user types/picks a team name themselves — stops auto-deriving it from members.
    @State private var hasEditedTeamName: Bool = false
    /// Reveals the name + color cards. Hidden until the members are filled (sticky once shown).
    @State private var hasRevealedDetails: Bool = false
    @State private var initialSnapshot: Snapshot?
    /// The player-count error waits until the host leaves the last player field,
    /// so it never scolds while they are still typing.
    @State private var isPlayerValidationVisible = false
    @State private var isDiscardConfirmationPresented = false
    @State private var addedPlayers = 0
    @State private var choiceChanges = 0

    @FocusState private var focusedField: Field?
    @ScaledMetric(relativeTo: .subheadline) private var playerBadgeSize: CGFloat = 24

    private var trimmedTeamName: String {
        teamName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPlayerNames: [String] {
        playerNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private var filledPlayerNames: [String] {
        trimmedPlayerNames.filter { !$0.isEmpty }
    }

    /// A team name built from the member names, e.g. "Anna & Ben".
    private var derivedTeamName: String {
        filledPlayerNames.joined(separator: " & ")
    }

    private var areAllPlayersFilled: Bool {
        playerNames.count >= minimumPlayers && filledPlayerNames.count == playerNames.count
    }

    /// Seats a new team starts with.
    private var defaultPlayers: Int { gameManager.configuration.playersPerTeam }
    private var minimumPlayers: Int { GameRules.minimumPlayersPerTeam }
    private var maximumPlayers: Int { gameManager.configuration.maxTeamMembers }
    private var canAddPlayer: Bool { playerNames.count < maximumPlayers }

    private var canSave: Bool {
        !trimmedTeamName.isEmpty && areAllPlayersFilled
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return trimmedTeamName != initialSnapshot.name
            || trimmedPlayerNames != initialSnapshot.players
            || !teamColor.isApproximatelyEqual(to: initialSnapshot.color)
    }

    private var title: String {
        team == nil ? localized("teamForm.title.new") : localized("teamForm.title.edit")
    }

    private var primaryButtonTitle: String {
        team == nil ? localized("teamForm.primary.create") : localized("teamForm.primary.save")
    }

    /// Colors the other teams already use; the team being edited is excluded.
    private var otherTeamColors: [Color] {
        gameManager.configuration.teams
            .filter { $0.id != team?.id }
            .map(\.color)
    }

    init(
        team: Team? = nil,
        onPrimaryAction: @escaping (Team) -> Void
    ) {
        self.team = team
        self.onPrimaryAction = onPrimaryAction
    }

    var body: some View {
        ScrollViewReader { proxy in
            formContent
                .haptic(.success, trigger: addedPlayers)
                .haptic(.selection, trigger: choiceChanges)
                .dismissesKeyboardInteractively()
                .onChange(of: focusedField) { previous, field in
                    handleFocusChange(from: previous, to: field, proxy: proxy)
                }
        }
        .navigationTitle(title)
        .inlineNavigationTitle()
        .setDefaultBackground()
        .toolbar {
            CloseToolbarItem(action: handleClose)
            ConfirmToolbarItem(title: primaryButtonTitle, canConfirm: canSave, action: handlePrimaryAction)
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .confirmationDialog(
            localized("common.discardChanges"),
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .hidden
        ) {
            Button(localized("common.discardChanges"), role: .destructive) { dismissSheet() }
            Button(localized("common.keepEditing"), role: .cancel) {}
        }
        .onAppear(perform: handleAppear)
        .onChange(of: playerNames) { _, _ in handlePlayerNamesChange() }
    }
}

// MARK: - Subviews
private extension TeamFormView {
    var formContent: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                playersCard

                if hasRevealedDetails {
                    teamNameCard
                        .id(Field.teamName)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    TeamColorCard(color: $teamColor, occupiedColors: otherTeamColors)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
    }

    var teamNameCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                TeamFormFieldLabel(icon: "textformat", title: "teamForm.teamName")

                TextField(localized("teamForm.enterTeamName"), text: teamNameBinding)
                    .focused($focusedField, equals: .teamName)
                    .hatFieldStyle(
                        label: localized("teamForm.teamName"),
                        font: DesignBook.Font.title3,
                        submitLabel: .done,
                        disablesAutocorrection: true,
                        capitalization: .words
                    ) {
                        focusedField = .teamName
                    }
                    .onSubmit { focusedField = nil }

                if showNameSuggestions {
                    TeamNameSuggestionRow(
                        suggestions: nameSuggestions,
                        onPick: pickSuggestion,
                        onRefresh: refreshSuggestions
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(reduceMotion ? nil : DesignBook.Motion.standard, value: showNameSuggestions)
    }

    var playersCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    TeamFormFieldLabel(icon: "person.2.fill", title: "teamForm.players")
                    Spacer()
                    Text(verbatim: "\(filledPlayerNames.count)/\(playerNames.count)")
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .monospacedDigit()
                }

                playersMessage

                VStack(spacing: DesignBook.Spacing.md) {
                    ForEach(playerNames.indices, id: \.self) { index in
                        playerField(index: index)
                            .id(Field.player(index))
                    }
                }

                if canAddPlayer {
                    addPlayerButton
                }
            }
        }
    }

    var addPlayerButton: some View {
        Button(action: addPlayer) {
            Label(localized("teamForm.addPlayer"), systemImage: "person.badge.plus")
                .font(DesignBook.Font.subheadlineSemibold)
                .foregroundStyle(DesignBook.Color.Text.accent)
        }
        .glassButtonStyle()
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .accessibilityIdentifier("teamForm.addPlayer")
    }

    /// Neutral guidance while the members are being typed; the error only
    /// once the host has moved past the last player field.
    @ViewBuilder
    var playersMessage: some View {
        if !areAllPlayersFilled {
            if isPlayerValidationVisible {
                Text(localized("teamForm.validation.fillAllPlayers"))
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Status.error)
            } else {
                Text(localized("teamForm.helper.players \(playerNames.count)"))
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            }
        }
    }

    func playerField(index: Int) -> some View {
        HStack(spacing: DesignBook.Spacing.md) {
            Text(verbatim: "\(index + 1)")
                .font(DesignBook.Font.subheadlineSemibold)
                .foregroundStyle(DesignBook.Color.Text.accent)
                .frame(width: playerBadgeSize, height: playerBadgeSize)
                .background(DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.highlight))
                .clipShape(Circle())
                .monospacedDigit()
                .accessibilityHidden(true)

            TextField(
                localized("teamForm.playerName"),
                text: Binding(
                    get: { playerNames[index] },
                    set: { playerNames[index] = $0 }
                )
            )
            .focused($focusedField, equals: .player(index))
            .hatFieldStyle(
                label: localized("teamForm.playerField \(index + 1)"),
                submitLabel: .next,
                contentType: .givenName,
                disablesAutocorrection: true,
                capitalization: .words
            ) { focusedField = .player(index) }
            .onSubmit { advanceFocus(fromPlayer: index) }

            // Seats past the minimum can go again, so a team can shrink back.
            if index >= minimumPlayers {
                Button(role: .destructive) {
                    removePlayer(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(DesignBook.IconFont.small)
                        .foregroundStyle(DesignBook.Color.Status.error)
                        .frame(minWidth: DesignBook.Size.touchTargetSize, minHeight: DesignBook.Size.touchTargetSize)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(localized("teamForm.removePlayer \(index + 1)")))
                .help(localized("teamForm.removePlayer \(index + 1)"))
            }
        }
    }
}

// MARK: - Derived state
private extension TeamFormView {
    /// Show inline suggestions whenever the user is focused on the team-name field,
    /// so they stay available even after it's been auto-filled from the members.
    var showNameSuggestions: Bool {
        focusedField == .teamName
    }

    /// Binding for the team-name field that records when the user edits it directly,
    /// so we stop overwriting their choice with the auto-derived name.
    var teamNameBinding: Binding<String> {
        Binding(
            get: { teamName },
            set: { newValue in
                teamName = newValue
                hasEditedTeamName = true
            }
        )
    }
}

// MARK: - Focus
private extension TeamFormView {
    /// Return moves through the players, then on to the team name. When a
    /// player is still missing, it goes back to the first empty field.
    func advanceFocus(fromPlayer index: Int) {
        if index + 1 < playerNames.count {
            focusedField = .player(index + 1)
        } else if let firstEmpty = trimmedPlayerNames.firstIndex(where: \.isEmpty) {
            isPlayerValidationVisible = true
            focusedField = .player(firstEmpty)
        } else {
            focusedField = .teamName
        }
    }

    /// Validates when focus leaves the last player field, and keeps the newly
    /// focused field in view above the keyboard.
    func handleFocusChange(from previous: Field?, to field: Field?, proxy: ScrollViewProxy) {
        let lastPlayer = Field.player(max(playerNames.count - 1, 0))
        if previous == lastPlayer, field != lastPlayer {
            isPlayerValidationVisible = true
        }
        guard let field else { return }
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            proxy.scrollTo(field, anchor: .center)
        }
    }
}

// MARK: - Actions
private extension TeamFormView {
    func handleAppear() {
        guard initialSnapshot == nil else { return }
        loadInitialData()
        initialSnapshot = Snapshot(name: trimmedTeamName, players: trimmedPlayerNames, color: teamColor)
        // Start the host straight on the first member field for a new team.
        if team == nil {
            focusedField = .player(0)
        }
    }

    /// Keeps the team name auto-derived from the members ("Anna & Ben") until the
    /// host edits it themselves, and reveals the name + color cards once all
    /// members are filled.
    func handlePlayerNamesChange() {
        if !hasEditedTeamName {
            teamName = derivedTeamName
        }
        if areAllPlayersFilled, !hasRevealedDetails {
            withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
                hasRevealedDetails = true
            }
        }
    }

    func pickSuggestion(_ name: String) {
        withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
            teamName = name
        }
        hasEditedTeamName = true
        choiceChanges += 1
        focusedField = nil
    }

    func refreshSuggestions() {
        let fresh = TeamNameSuggestions.random()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
            nameSuggestions = fresh
        }
    }

    func loadInitialData() {
        if let team {
            teamName = team.name
            var names = team.players.map(\.name)
            var ids: [Player.ID?] = team.players.map(\.id)
            while names.count < minimumPlayers {
                names.append("")
                ids.append(nil)
            }
            playerNames = names
            playerIds = ids
            teamColor = team.color
            // Editing an existing team: keep its name and show everything up front.
            hasEditedTeamName = true
            hasRevealedDetails = true
        } else {
            teamName = ""
            playerNames = Array(repeating: "", count: defaultPlayers)
            playerIds = Array(repeating: nil, count: defaultPlayers)
            teamColor = TeamDefaultColorGenerator().generateDefaultColor(for: gameManager.configuration)
            hasEditedTeamName = false
            hasRevealedDetails = false
        }
    }

    /// Closing keeps nothing, so it asks first when something changed.
    func handleClose() {
        if hasUnsavedChanges {
            isDiscardConfirmationPresented = true
        } else {
            dismissSheet()
        }
    }

    func addPlayer() {
        guard canAddPlayer else { return }
        withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
            playerNames.append("")
            playerIds.append(nil)
        }
        addedPlayers += 1
        focusedField = .player(playerNames.count - 1)
    }

    func removePlayer(at index: Int) {
        guard index >= minimumPlayers, playerNames.indices.contains(index) else { return }
        if focusedField == .player(index) {
            focusedField = nil
        }
        _ = withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
            playerNames.remove(at: index)
        }
        playerIds.remove(at: index)
        choiceChanges += 1
    }

    func handlePrimaryAction() {
        guard canSave else { return }

        let teamId = team?.id ?? UUID()
        // Each seat keeps its player's id, so words they already put in the
        // hat stay theirs when the team is edited (a renamed typo, a new color).
        let players = filledPlayerNames.enumerated().map { index, name in
            Player(id: playerIds[safe: index].flatMap { $0 } ?? UUID(), name: name, teamId: teamId)
        }
        let updatedTeam = Team(id: teamId, name: trimmedTeamName, players: players, color: teamColor)

        onPrimaryAction(updatedTeam)
        dismissSheet()
    }
}
