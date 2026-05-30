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
    @State private var isColorSectionExpanded: Bool = false
    @State private var nameSuggestions: [String] = TeamNameSuggestions.random()

    @FocusState private var focusedField: Field?

    private let appConfiguration = AppConfiguration.shared

    private var isKeyboardVisible: Bool { focusedField != nil }

    private var trimmedTeamName: String {
        teamName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filledPlayerNames: [String] {
        playerNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var requiredPlayers: Int { gameManager.configuration.playersPerTeam }

    private var canSave: Bool {
        !trimmedTeamName.isEmpty && filledPlayerNames.count == requiredPlayers
    }

    private var validationMessage: String? {
        guard !trimmedTeamName.isEmpty, filledPlayerNames.count < requiredPlayers else {
            return nil
        }
        return String(format: String(localized: "teamForm.validation.exactPlayers"), requiredPlayers)
    }

    private var title: String {
        team == nil ? String(localized: "teamForm.title.new") : String(localized: "teamForm.title.edit")
    }

    private var primaryButtonTitle: String {
        team == nil ? String(localized: "teamForm.primary.create") : String(localized: "teamForm.primary.save")
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
                teamNameCard
                teamColorCard
                playersCard
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .navigationTitle(title)
        .setDefaultStyle()
        .safeAreaInset(edge: .bottom) {
            stackedActions
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.md)
                .padding(.bottom, DesignBook.Spacing.md)
                .withFooterGradient()
        }
        .onAppear(perform: handleAppear)
    }
}

// MARK: - Subviews
private extension TeamFormView {
    var teamNameCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                FieldLabel(icon: "person.3.fill", title: "teamForm.teamName")

                TextField("teamForm.enterTeamName", text: $teamName)
                    .textFieldStyle(.plain)
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .padding(DesignBook.Spacing.md)
                    .background(DesignBook.Color.Background.secondary)
                    .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                    .focused($focusedField, equals: .teamName)
                    .onSubmit {
                        if !playerNames.isEmpty {
                            focusedField = .player(0)
                        }
                    }

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

    var teamColorCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                colorCardHeader

                if isColorSectionExpanded {
                    colorPicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    var colorCardHeader: some View {
        Button {
            withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
                isColorSectionExpanded.toggle()
            }
        } label: {
            HStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: "paintpalette.fill")
                    .font(DesignBook.IconFont.medium)
                    .foregroundStyle(DesignBook.Color.Text.accent)

                Text("teamForm.teamColor")
                    .font(DesignBook.Font.captionBold)
                    .foregroundStyle(DesignBook.Color.Text.secondary)

                Spacer()

                if !isColorSectionExpanded {
                    Circle()
                        .fill(teamColor)
                        .frame(width: 24, height: 24)
                }

                Image(systemName: isColorSectionExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    var colorPicker: some View {
        HStack {
            if appConfiguration.isRightHanded {
                Spacer()
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: DesignBook.Size.colorSwatchSize), spacing: DesignBook.Spacing.md)],
                spacing: DesignBook.Spacing.md
            ) {
                ForEach(suggestedColorOptions.indices, id: \.self) { index in
                    ColorSwatchButton(
                        color: suggestedColorOptions[index],
                        isSelected: isColorSelected(suggestedColorOptions[index]),
                        isDisabled: isColorOccupiedByOtherTeam(suggestedColorOptions[index]),
                        onSelect: { selectColor(suggestedColorOptions[index]) }
                    )
                }

                ColorPicker(
                    "teamForm.customColor",
                    selection: Binding(
                        get: { teamColor },
                        set: { selectColor($0) }
                    ),
                    supportsOpacity: true
                )
                .labelsHidden()
                .frame(width: DesignBook.Size.colorSwatchSize, height: DesignBook.Size.colorSwatchSize)
                .padding(DesignBook.Spacing.sm)
                .background(DesignBook.Color.Background.secondary)
                .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                .contentShape(Rectangle())
            }
        }
    }

    var playersCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    FieldLabel(icon: "person.2.fill", title: "teamForm.players")
                    Spacer()
                    Text(verbatim: "\(filledPlayerNames.count)/\(requiredPlayers)")
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .monospacedDigit()
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(DesignBook.Font.caption)
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
                .font(DesignBook.Font.captionBold)
                .foregroundStyle(DesignBook.Color.Text.accent)
                .frame(width: 24, height: 24)
                .background(DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.highlight))
                .clipShape(Circle())
                .monospacedDigit()

            TextField(
                "teamForm.playerName",
                text: Binding(
                    get: { playerNames[index] },
                    set: { playerNames[index] = $0 }
                )
            )
            .textFieldStyle(.plain)
            .font(DesignBook.Font.body)
            .foregroundStyle(DesignBook.Color.Text.primary)
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.secondary)
            .cornerRadius(DesignBook.Size.smallCardCornerRadius)
            .focused($focusedField, equals: .player(index))
            .onSubmit {
                let nextIndex = index + 1
                focusedField = nextIndex < playerNames.count ? .player(nextIndex) : nil
            }
        }
    }

    @ViewBuilder
    var stackedActions: some View {
        if isKeyboardVisible {
            HStack(spacing: DesignBook.Spacing.md) {
                DestructiveButton(title: String(localized: "common.buttons.cancel"), action: dismiss)
                    .frame(maxWidth: .infinity)
                primarySubmitButton
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: DesignBook.Spacing.md) {
                primarySubmitButton
                DestructiveButton(title: String(localized: "common.buttons.cancel"), action: dismiss)
            }
        }
    }

    var primarySubmitButton: some View {
        PrimaryButton(title: primaryButtonTitle, icon: primaryButtonIcon, action: handlePrimaryAction)
            .disabled(!canSave)
            .opacity(canSave ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
    }

    var suggestedColorOptions: [Color] {
        TeamDefaultColorGenerator.defaultColors
    }
}

// MARK: - Derived state
private extension TeamFormView {
    /// Show inline suggestions only when the user is actively focused on the team-name
    /// field with no text yet — i.e. they're looking for inspiration, not editing.
    var showNameSuggestions: Bool {
        focusedField == .teamName && trimmedTeamName.isEmpty
    }

    func isColorSelected(_ color: Color) -> Bool {
        teamColor.isApproximatelyEqual(to: color)
    }

    func isColorOccupiedByOtherTeam(_ color: Color) -> Bool {
        gameManager.configuration.teams.contains { other in
            // Skip the current team if editing.
            if other.id == team?.id { return false }
            return color.isApproximatelyEqual(to: other.color)
        }
    }
}

// MARK: - Actions
private extension TeamFormView {
    func handleAppear() {
        loadInitialData()
        if teamName.isEmpty {
            focusedField = .teamName
        }
    }

    func selectColor(_ color: Color) {
        DesignBook.Haptics.selection()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            teamColor = color
            isColorSectionExpanded = false
        }
    }

    func pickSuggestion(_ name: String) {
        DesignBook.Haptics.tap()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
            teamName = name
        }
        // Advance focus so the user can keep moving without an extra tap.
        focusedField = playerNames.isEmpty ? nil : .player(0)
    }

    func refreshSuggestions() {
        DesignBook.Haptics.selection()
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
        } else {
            teamName = ""
            playerNames = Array(repeating: "", count: requiredPlayers)
            teamColor = TeamDefaultColorGenerator().generateDefaultColor(for: gameManager.configuration)
        }
    }

    func handlePrimaryAction() {
        guard !trimmedTeamName.isEmpty else { return }
        DesignBook.Haptics.confirm()

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

    func dismiss() {
        DesignBook.Haptics.tap()
        dismissSheet()
    }
}

// MARK: - Subview types
private struct FieldLabel: View {
    let icon: String
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignBook.IconFont.medium)
                .foregroundStyle(DesignBook.Color.Text.accent)

            Text(title)
                .font(DesignBook.Font.captionBold)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
    }
}

/// Inline row of tappable team-name suggestions with a shuffle button.
/// Appears below the team-name field when it's focused and empty.
private struct TeamNameSuggestionRow: View {
    let suggestions: [String]
    let onPick: (String) -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            header

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        SuggestionChip(text: suggestion) {
                            onPick(suggestion)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("teamForm.suggestions.accessibility"))
    }

    private var header: some View {
        HStack(spacing: DesignBook.Spacing.xs) {
            Image(systemName: "wand.and.stars")
                .font(DesignBook.Font.smallCaption)
                .foregroundStyle(DesignBook.Color.Text.accent)

            Text("teamForm.suggestions.title")
                .font(DesignBook.Font.smallCaption)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(DesignBook.Color.Text.tertiary)

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "shuffle")
                    .font(DesignBook.Font.captionBold)
                    .foregroundStyle(DesignBook.Color.Text.accent)
                    .padding(6)
                    .background {
                        Circle().fill(DesignBook.Color.Text.accent.opacity(0.12))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("teamForm.suggestions.shuffle"))
        }
    }
}

private struct SuggestionChip: View {
    let text: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(DesignBook.Font.captionBold)
                .foregroundStyle(DesignBook.Color.Text.accent)
                .lineLimit(1)
                .padding(.horizontal, DesignBook.Spacing.md)
                .padding(.vertical, DesignBook.Spacing.sm)
                .background {
                    Capsule()
                        .fill(DesignBook.Color.Text.accent.opacity(0.10))
                        .overlay {
                            Capsule()
                                .strokeBorder(DesignBook.Color.Text.accent.opacity(0.30), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(text)"))
        .accessibilityHint(Text("teamForm.suggestions.tap"))
    }
}

private struct ColorSwatchButton: View {
    let color: Color
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Circle()
                .fill(color)
                .frame(width: DesignBook.Size.colorSwatchSize, height: DesignBook.Size.colorSwatchSize)
                .overlay(overlay)
                .opacity(isDisabled ? DesignBook.Opacity.disabled : DesignBook.Opacity.enabled)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(isSelected ? Text("teamForm.color.swatch.selected") : Text("teamForm.color.swatch.unselected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var overlay: some View {
        if isSelected {
            Image(systemName: "checkmark")
                .font(DesignBook.Font.subheadlineBold)
                .foregroundStyle(.white)
        } else if isDisabled {
            Image(systemName: "xmark")
                .font(DesignBook.Font.footnoteBold)
                .foregroundStyle(.white)
                .opacity(DesignBook.Opacity.disabled)
        }
    }
}
