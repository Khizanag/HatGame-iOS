//
//  TeamSetupView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct TeamSetupView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var isAddTeamSheetPresented = false
    @State private var editingTeam: Team?
    @State private var deletingTeam: Team?
    @State private var isEditing: Bool = false
    @State private var isDiscardConfirmationPresented = false

    private var teams: [Team] { gameManager.configuration.teams }
    private var isEditMode: Bool { isEditing }
    private var hasTeams: Bool { !teams.isEmpty }
    private var canAddMore: Bool { teams.count < gameManager.configuration.maxTeams }
    private var canReorder: Bool { teams.count >= 2 }

    private var canContinue: Bool {
        (gameManager.configuration.minTeams...gameManager.configuration.maxTeams)
            .contains(teams.count)
    }

    // MARK: - Body
    var body: some View {
        content
            .editModeEnvironment(isEditing: $isEditing)
            .navigationTitle(localized("teamSetup.title"))
            .inlineNavigationTitle()
            .setDefaultBackground()
            .toolbar { toolbarContent }
            .confirmationDialog(
                localized("teamSetup.discard.title"),
                isPresented: $isDiscardConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(localized("common.discardChanges"), role: .destructive) { dismiss() }
                Button(localized("common.keepEditing"), role: .cancel) {}
            } message: {
                Text(localized("teamSetup.discard.message"))
            }
            .sheet(isPresented: $isAddTeamSheetPresented) {
                NavigationStack {
                    AddTeamView(
                        onTeamCreate: { team in
                            gameManager.addTeam(team)
                        }
                    )
                }
                .environment(navigator)
                .environment(gameManager)
            }
            .sheet(isPresented: editTeamBinding) {
                editTeamSheet
            }
            .alert(localized("teamSetup.deleteTeam.title"), isPresented: isDeleteTeamAlertPresented) {
                deleteTeamAlertActions
            } message: {
                deleteTeamAlertMessage
            }
    }
}

// MARK: - Layout
private extension TeamSetupView {
    var content: some View {
        VStack(spacing: 0) {
            headerCard
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.md)
                .padding(.bottom, DesignBook.Spacing.md)

            if hasTeams {
                populatedList
                    .actionBar {
                        continueSection
                            .paddingHorizontalDefault()
                    }
            } else {
                emptyState
                    .frame(maxHeight: .infinity)
            }
        }
    }

    var headerCard: some View {
        HeaderCard(description: localized("teamSetup.description"))
    }

    var populatedList: some View {
        List {
            teamsList

            if !isEditMode, canAddMore {
                addTeamButtonRow
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    var teamsList: some View {
        ForEach(teams) { team in
            teamRow(for: team)
        }
        .onMove(perform: moveTeam)
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label(localized("teamSetup.empty.title"), systemImage: "person.2")
        } description: {
            Text(localized("teamSetup.empty.description \(gameManager.configuration.minTeams)"))
        } actions: {
            SecondaryButton(
                title: localized("teamSetup.addTeam"),
                icon: "plus.circle.fill"
            ) {
                isAddTeamSheetPresented = true
            }
            .paddingHorizontalDefault()
        }
    }

    var continueSection: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            PrimaryButton(title: localized("common.buttons.continue"), icon: "arrow.right.circle.fill") {
                navigator.push(.wordSettings)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canContinue)

            if !canContinue {
                requirementText
            }
        }
    }

    var requirementText: some View {
        Text(localized("teamSetup.minTeamsRequired \(gameManager.configuration.minTeams)"))
            .font(DesignBook.Font.subheadline)
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .multilineTextAlignment(.center)
            .paddingHorizontalDefault()
    }
}

// MARK: - Row
private extension TeamSetupView {
    func teamRow(for team: Team) -> some View {
        Button {
            editingTeam = team
        } label: {
            TeamCard(team: team)
        }
        .buttonStyle(.plain)
        .pointerHoverEffect()
        .paddingHorizontalDefault()
        .padding(.vertical, DesignBook.Spacing.sm)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityLabel(Text(rowAccessibilityLabel(for: team)))
        .accessibilityHint(Text(localized("teamSetup.editTeam.a11yHint")))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteSwipeAction(for: team)
            editSwipeAction(for: team)
        }
        .contextMenu {
            Button {
                editingTeam = team
            } label: {
                Label(localized("common.buttons.edit"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletingTeam = team
            } label: {
                Label(localized("common.buttons.delete"), systemImage: "trash")
            }
        }
    }

    /// "Alpha, players: Ann and Ben" — the members, not just the name.
    func rowAccessibilityLabel(for team: Team) -> String {
        let members = team.players
            .map(\.name)
            .formatted(.list(type: .and).locale(AppConfiguration.shared.locale))
        return String(format: localized("teamSetup.teamRow.a11y %@ %@"), team.name, members)
    }

    func deleteSwipeAction(for team: Team) -> some View {
        Button(role: .destructive) {
            deletingTeam = team
        } label: {
            Label(localized("teamCard.delete"), systemImage: "trash")
        }
    }

    func editSwipeAction(for team: Team) -> some View {
        Button {
            editingTeam = team
        } label: {
            Label(localized("teamCard.edit"), systemImage: "pencil")
        }
        .tint(DesignBook.Color.Text.accent)
    }

    var addTeamButtonRow: some View {
        SecondaryButton(
            title: localized("teamSetup.addTeam"),
            icon: "plus.circle.fill"
        ) {
            isAddTeamSheetPresented = true
        }
        .paddingHorizontalDefault()
        .padding(.vertical, DesignBook.Spacing.xs)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    func moveTeam(from source: IndexSet, to destination: Int) {
        withAnimation(DesignBook.Motion.respectingReducedMotion(.smooth, reduceMotion: reduceMotion)) {
            gameManager.moveTeam(from: source, to: destination)
        }
    }
}

// MARK: - Toolbar
private extension TeamSetupView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        CloseToolbarItem(action: handleClose)
        #if !os(macOS)
        if canReorder {
            ToolbarItem(placement: .trailingAction) {
                editToggleButton
            }
            // A text item beside a symbol reads as one action; the HIG keeps
            // them in separate groups. visionOS has no toolbar spacer.
            #if os(iOS)
            if canAddMore {
                ToolbarSpacer(.fixed, placement: .trailingAction)
            }
            #endif
        }
        #endif
        if canAddMore {
            ToolbarItem(placement: .trailingAction) {
                Button {
                    isAddTeamSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(localized("teamSetup.addTeam")))
                .help(localized("teamSetup.addTeam"))
            }
        }
    }

    /// Closing the setup drops every team added so far, so it asks first.
    func handleClose() {
        if hasTeams {
            isDiscardConfirmationPresented = true
        } else {
            dismiss()
        }
    }

    var editToggleButton: some View {
        Button {
            withAnimation(DesignBook.Motion.respectingReducedMotion(.snappy, reduceMotion: reduceMotion)) {
                isEditing.toggle()
            }
        } label: {
            Text(isEditMode ? localized("common.buttons.done") : localized("common.buttons.edit"))
                .fontWeight(isEditMode ? .semibold : .regular)
        }
    }
}

// MARK: - Sheets and alerts
private extension TeamSetupView {
    var editTeamBinding: Binding<Bool> {
        Binding(
            get: { editingTeam != nil },
            set: { if !$0 { editingTeam = nil } }
        )
    }

    @ViewBuilder
    var editTeamSheet: some View {
        if let team = editingTeam {
            NavigationStack {
                TeamEditView(team: team)
            }
            .environment(navigator)
            .environment(gameManager)
        }
    }

    var isDeleteTeamAlertPresented: Binding<Bool> {
        Binding(
            get: { deletingTeam != nil },
            set: { if !$0 { deletingTeam = nil } }
        )
    }

    @ViewBuilder
    var deleteTeamAlertActions: some View {
        Button(localized("common.buttons.cancel"), role: .cancel) {
            deletingTeam = nil
        }
        Button(localized("teamSetup.deleteTeam.title"), role: .destructive) {
            if let deletingTeam {
                DesignBook.Haptics.rigid()
                withAnimation(DesignBook.Motion.respectingReducedMotion(.smooth, reduceMotion: reduceMotion)) {
                    gameManager.removeTeam(deletingTeam)
                }
                self.deletingTeam = nil
            }
        }
    }

    @ViewBuilder
    var deleteTeamAlertMessage: some View {
        if let deletingTeam {
            Text(String(format: localized("teamSetup.deleteTeam.confirmation"), deletingTeam.name))
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        TeamSetupView()
    }
    .environment(Navigator())
    .environment(GameManager())
}
