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
    private let appConfiguration = AppConfiguration.shared

    @State private var isAddTeamSheetPresented = false
    @State private var editingTeam: Team?
    @State private var deletingTeam: Team?
    @State private var editMode: EditMode = .inactive

    private var teams: [Team] { gameManager.configuration.teams }
    private var isEditMode: Bool { editMode == .active }
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
            .environment(\.editMode, $editMode)
            .navigationTitle(String(localized: "teamSetup.title"))
            .setDefaultStyle()
            .toolbar { toolbarContent }
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
            .alert(String(localized: "teamSetup.deleteTeam.title"), isPresented: isDeleteTeamAlertPresented) {
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
                continueSection
                    .paddingHorizontalDefault()
                    .withFooterGradient()
            } else {
                emptyState
                    .frame(maxHeight: .infinity)
            }
        }
    }

    var headerCard: some View {
        HeaderCard(
            title: String(localized: "teamSetup.title"),
            description: String(localized: "teamSetup.description")
        )
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
            Label(String(localized: "teamSetup.empty.title"), systemImage: "person.3")
        } description: {
            Text(String(
                format: String(localized: "teamSetup.empty.description"),
                gameManager.configuration.minTeams
            ))
        } actions: {
            SecondaryButton(
                title: String(localized: "teamSetup.addTeam"),
                icon: "plus.circle.fill"
            ) {
                DesignBook.Haptics.tap()
                isAddTeamSheetPresented = true
            }
            .paddingHorizontalDefault()
        }
    }

    var continueSection: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            PrimaryButton(title: String(localized: "common.buttons.continue"), icon: "arrow.right.circle.fill") {
                DesignBook.Haptics.tap()
                navigator.push(.wordSettings)
            }
            .disabled(!canContinue)
            .opacity(canContinue ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)

            if !canContinue {
                requirementText
            }
        }
    }

    var requirementText: some View {
        Text(String(format: String(localized: "teamSetup.minTeamsRequired"), gameManager.configuration.minTeams))
            .font(DesignBook.Font.caption)
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .multilineTextAlignment(.center)
            .paddingHorizontalDefault()
    }
}

// MARK: - Row
private extension TeamSetupView {
    func teamRow(for team: Team) -> some View {
        Button {
            DesignBook.Haptics.tap()
            editingTeam = team
        } label: {
            TeamCard(team: team, playersPerTeam: gameManager.configuration.playersPerTeam)
        }
        .buttonStyle(.plain)
        .paddingHorizontalDefault()
        .padding(.vertical, DesignBook.Spacing.sm)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityLabel(Text(String(format: String(localized: "teamSetup.editTeam.a11y %@"), team.name)))
        .accessibilityHint(Text("teamSetup.editTeam.a11yHint"))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteSwipeAction(for: team)
            editSwipeAction(for: team)
        }
        .contextMenu {
            Button {
                editingTeam = team
            } label: {
                Label(String(localized: "common.buttons.edit"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletingTeam = team
            } label: {
                Label(String(localized: "common.buttons.delete"), systemImage: "trash")
            }
        }
    }

    func deleteSwipeAction(for team: Team) -> some View {
        Button(role: .destructive) {
            deletingTeam = team
        } label: {
            Label(String(localized: "teamCard.delete"), systemImage: "trash")
        }
    }

    func editSwipeAction(for team: Team) -> some View {
        Button {
            editingTeam = team
        } label: {
            Label(String(localized: "teamCard.edit"), systemImage: "pencil")
        }
        .tint(DesignBook.Color.Text.accent)
    }

    var addTeamButtonRow: some View {
        SecondaryButton(
            title: String(localized: "teamSetup.addTeam"),
            icon: "plus.circle.fill"
        ) {
            DesignBook.Haptics.tap()
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
        if canReorder {
            ToolbarItem(placement: .topBarTrailing) {
                editToggleButton
            }
        }
        if canAddMore {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    DesignBook.Haptics.tap()
                    isAddTeamSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("teamSetup.addTeam"))
            }
        }
    }

    var editToggleButton: some View {
        Button {
            DesignBook.Haptics.tap()
            withAnimation(DesignBook.Motion.respectingReducedMotion(.snappy, reduceMotion: reduceMotion)) {
                editMode = isEditMode ? .inactive : .active
            }
        } label: {
            Text(isEditMode ? "common.buttons.done" : "common.buttons.edit")
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
        Button(String(localized: "common.buttons.cancel"), role: .cancel) {
            deletingTeam = nil
        }
        Button(String(localized: "teamSetup.deleteTeam.title"), role: .destructive) {
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
            Text(String(format: String(localized: "teamSetup.deleteTeam.confirmation"), deletingTeam.name))
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
