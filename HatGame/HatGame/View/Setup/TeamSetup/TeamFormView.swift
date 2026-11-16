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

    @Environment(GameManager.self) private var gameManager
    @Environment(\.dismiss) private var dismissSheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let team: Team?
    let onPrimaryAction: (Team) -> Void

    @State private var teamName: String = ""
    @State private var playerNames: [String] = []
    @State private var teamColor: Color = TeamDefaultColorGenerator.defaultColors[0]
    @State private var nameSuggestions: [String] = TeamNameSuggestions.random()
    /// True once the user types/picks a team name themselves — stops auto-deriving it from members.
    @State private var hasEditedTeamName: Bool = false
    /// Reveals the name + color cards. Hidden until the members are filled (sticky once shown).
    @State private var hasRevealedDetails: Bool = false

    @FocusState private var focusedField: Field?
    @ScaledMetric(relativeTo: .subheadline) private var playerBadgeSize: CGFloat = 24

    private var trimmedTeamName: String {
        teamName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filledPlayerNames: [String] {
        playerNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// A team name built from the member names, e.g. "Anna & Ben".
    private var derivedTeamName: String {
        filledPlayerNames.joined(separator: " & ")
    }

    private var areAllPlayersFilled: Bool {
        filledPlayerNames.count == requiredPlayers
    }

    private var requiredPlayers: Int { gameManager.configuration.playersPerTeam }

    private var canSave: Bool {
        !trimmedTeamName.isEmpty && filledPlayerNames.count == requiredPlayers
    }

    private var validationMessage: String? {
        guard !trimmedTeamName.isEmpty, filledPlayerNames.count < requiredPlayers else {
            return nil
        }
        return localized("teamForm.validation.exactPlayers \(requiredPlayers)")
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

    private var primaryButtonIcon: String {
        team == nil ? "plus.circle.fill" : "checkmark.circle.fill"
    }

    init(
        team: Team? = nil,
        onPrimaryAction: @escaping (Team) -> Void
    ) {
        self.team = team
        self.onPrimaryAction = onPrimaryAction
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                playersCard

                if hasRevealedDetails {
                    teamNameCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    TeamColorCard(color: $teamColor, occupiedColors: otherTeamColors)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .navigationTitle(title)
        .setDefaultStyle()
        .actionBar {
            stackedActions
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.md)
                .padding(.bottom, DesignBook.Spacing.md)
        }
        .onAppear(perform: handleAppear)
        .onChange(of: playerNames) { _, _ in handlePlayerNamesChange() }
    }
}

// MARK: - Subviews
private extension TeamFormView {
    var teamNameCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                TeamFormFieldLabel(icon: "person.3.fill", title: "teamForm.teamName")

                TextField(localized("teamForm.enterTeamName"), text: teamNameBinding)
                    .focused($focusedField, equals: .teamName)
                    .hatFieldStyle(label: localized("teamForm.teamName"), font: DesignBook.Font.title3) {
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
                    Text(verbatim: "\(filledPlayerNames.count)/\(requiredPlayers)")
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .monospacedDigit()
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Status.error)
                }

                VStack(spacing: DesignBook.Spacing.md) {
                    ForEach(playerNames.indices, id: \.self) { index in
                        playerField(index: index)
                    }
                }
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
                contentType: .givenName,
                disablesAutocorrection: true
            ) { focusedField = .player(index) }
            .onSubmit {
                let nextIndex = index + 1
                focusedField = nextIndex < playerNames.count ? .player(nextIndex) : nil
            }
        }
    }

    var stackedActions: some View {
        primarySubmitButton
    }

    var primarySubmitButton: some View {
        PrimaryButton(title: primaryButtonTitle, icon: primaryButtonIcon, action: handlePrimaryAction)
            .disabled(!canSave)
            .opacity(canSave ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
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

// MARK: - Actions
private extension TeamFormView {
    func handleAppear() {
        loadInitialData()
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
            while names.count < requiredPlayers { names.append("") }
            if names.count > requiredPlayers { names = Array(names.prefix(requiredPlayers)) }
            playerNames = names
            teamColor = team.color
            // Editing an existing team: keep its name and show everything up front.
            hasEditedTeamName = true
            hasRevealedDetails = true
        } else {
            teamName = ""
            playerNames = Array(repeating: "", count: requiredPlayers)
            teamColor = TeamDefaultColorGenerator().generateDefaultColor(for: gameManager.configuration)
            hasEditedTeamName = false
            hasRevealedDetails = false
        }
    }

    func handlePrimaryAction() {
        guard !trimmedTeamName.isEmpty else { return }

        let teamId = team?.id ?? UUID()
        let updatedTeam = Team(
            id: teamId,
            name: trimmedTeamName,
            players: filledPlayerNames.map { Player(name: $0, teamId: teamId) },
            color: teamColor
        )

        onPrimaryAction(updatedTeam)
        dismissSheet()
    }
}
