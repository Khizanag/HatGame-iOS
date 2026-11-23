//
//  OnlineTeamCreationView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct OnlineTeamCreationView: View {
    enum Field: Hashable { case name }

    @Environment(\.dismiss) private var dismiss
    @Environment(RoomManager.self) private var roomManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var teamName: String = ""
    @State private var teamColor: Color = TeamDefaultColorGenerator.defaultColors[0]
    @State private var isCreating: Bool = false
    @State private var isDiscardConfirmationPresented: Bool = false
    @State private var error: Error?
    @State private var completedActions = 0

    @FocusState private var focusedField: Field?

    private var trimmedName: String {
        teamName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool { !trimmedName.isEmpty && !isCreating }

    /// A typed name is the only input worth protecting; the color is
    /// preselected.
    private var hasUnsavedChanges: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(localized("createTeam.title"))
                .inlineNavigationTitle()
                .toolbar {
                    CloseToolbarItem(action: close)
                    ConfirmToolbarItem(
                        title: localized("createTeam.confirm"),
                        canConfirm: canCreate,
                        action: createTeam
                    )
                }
                .setDefaultBackground()
                .interactiveDismissDisabled(hasUnsavedChanges)
                .confirmationDialog(
                    localized("createTeam.discard.title"),
                    isPresented: $isDiscardConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button(localized("createTeam.discard.confirm"), role: .destructive) { dismiss() }
                    Button(localized("createTeam.discard.keepEditing"), role: .cancel) { }
                }
                .errorAlert($error, title: localized("error.title.createTeam"), retry: createTeam)
                .haptic(.success, trigger: completedActions)
        }
    }
}

// MARK: - Composition
private extension OnlineTeamCreationView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                nameCard
                colorCard
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .overlay {
            if isCreating {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .onAppear {
            focusedField = .name
            selectAvailableColor()
        }
    }

    var nameCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "textformat")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                    Text(localized("createTeam.teamName"))
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
                TextField(localized("createTeam.enterName"), text: $teamName)
                    .focused($focusedField, equals: .name)
                    .hatFieldStyle(
                        label: localized("createTeam.teamName"),
                        font: DesignBook.Font.title3,
                        submitLabel: .done,
                        disablesAutocorrection: true
                    ) {
                        focusedField = .name
                    }
                    .onSubmit(createTeam)
            }
        }
    }

    var colorCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "paintpalette.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                    Text(localized("createTeam.teamColor"))
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                    Spacer()
                    Circle().fill(teamColor).frame(width: 24, height: 24)
                }
                colorPicker
            }
        }
    }

    var colorPicker: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: DesignBook.Size.colorSwatchSize), spacing: DesignBook.Spacing.md)],
            spacing: DesignBook.Spacing.md
        ) {
            ForEach(TeamDefaultColorGenerator.defaultColors.indices, id: \.self) { index in
                colorOption(TeamDefaultColorGenerator.defaultColors[index])
            }
            ColorPicker(localized("createTeam.teamColor"), selection: $teamColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: DesignBook.Size.colorSwatchSize, height: DesignBook.Size.colorSwatchSize)
                .padding(DesignBook.Spacing.sm)
                .background(DesignBook.Color.Background.secondary)
                .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
        }
    }

    func colorOption(_ color: Color) -> some View {
        let isSelected = teamColor.isApproximatelyEqual(to: color)
        let isUsed = isColorUsedByOtherTeam(color)

        return Button {
            guard !isUsed else { return }
            withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
                teamColor = color
            }
        } label: {
            Circle()
                .fill(color)
                .frame(width: DesignBook.Size.colorSwatchSize, height: DesignBook.Size.colorSwatchSize)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(DesignBook.Font.bodyBold)
                            .foregroundStyle(DesignBook.Color.onAccent(for: color))
                    } else if isUsed {
                        Image(systemName: "xmark")
                            .font(DesignBook.Font.footnoteBold)
                            .foregroundStyle(DesignBook.Color.onAccent(for: color))
                            .opacity(DesignBook.Opacity.disabled)
                    }
                }
                .opacity(isUsed ? DesignBook.Opacity.disabled : DesignBook.Opacity.enabled)
        }
        .buttonStyle(.plain)
        .disabled(isUsed)
    }

    func isColorUsedByOtherTeam(_ color: Color) -> Bool {
        guard let teams = roomManager.room?.teams else { return false }
        return teams.contains { team in
            guard let teamColor = Color(hex: team.colorHex) else { return false }
            return color.isApproximatelyEqual(to: teamColor)
        }
    }

    func selectAvailableColor() {
        if let color = TeamDefaultColorGenerator.defaultColors.first(where: { !isColorUsedByOtherTeam($0) }) {
            teamColor = color
        }
    }
}

// MARK: - Actions
private extension OnlineTeamCreationView {
    func close() {
        if hasUnsavedChanges {
            isDiscardConfirmationPresented = true
        } else {
            dismiss()
        }
    }

    func createTeam() {
        guard canCreate else { return }
        isCreating = true
        focusedField = nil
        let name = trimmedName
        let colorHex = teamColor.hexString

        Task {
            do {
                try await roomManager.createTeam(name: name, colorHex: colorHex)
                completedActions += 1
                dismiss()
            } catch {
                self.error = error
            }
            isCreating = false
        }
    }
}

#Preview {
    OnlineTeamCreationView()
        .environment(RoomManager())
}
