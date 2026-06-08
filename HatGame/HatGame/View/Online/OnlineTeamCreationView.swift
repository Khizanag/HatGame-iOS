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
    @State private var error: Error?

    @FocusState private var focusedField: Field?

    private var trimmedName: String {
        teamName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool { !trimmedName.isEmpty && !isCreating }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(localized("createTeam.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(DesignBook.Color.Text.primary)
                        }
                    }
                    keyboardToolbar
                }
                .setDefaultBackground()
                .alert("common.error", isPresented: errorBinding) {
                    Button("common.gotIt") { error = nil }
                } message: {
                    Text(error?.localizedDescription ?? "")
                }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
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
        .safeAreaInset(edge: .bottom) {
            if focusedField == nil {
                primaryButton
                    .paddingHorizontalDefault()
                    .padding(.top, DesignBook.Spacing.md)
                    .padding(.bottom, DesignBook.Spacing.sm)
                    .withFooterGradient()
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
                    Image(systemName: "person.3.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text(localized("createTeam.teamName"))
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
                TextField("createTeam.enterName", text: $teamName)
                    .textFieldStyle(.plain)
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .padding(DesignBook.Spacing.md)
                    .background(DesignBook.Color.Background.secondary)
                    .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                    .focused($focusedField, equals: .name)
            }
        }
    }

    var colorCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "paintpalette.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text(localized("createTeam.teamColor"))
                        .font(DesignBook.Font.captionBold)
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
            ColorPicker("", selection: $teamColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: DesignBook.Size.colorSwatchSize, height: DesignBook.Size.colorSwatchSize)
                .padding(DesignBook.Spacing.sm)
                .background(DesignBook.Color.Background.secondary)
                .cornerRadius(DesignBook.Size.smallCardCornerRadius)
        }
    }

    func colorOption(_ color: Color) -> some View {
        let isSelected = teamColor.isApproximatelyEqual(to: color)
        let isUsed = isColorUsedByOtherTeam(color)

        return Button {
            guard !isUsed else { return }
            DesignBook.Haptics.selection()
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
                            .font(DesignBook.Font.subheadlineBold)
                            .foregroundStyle(.white)
                    } else if isUsed {
                        Image(systemName: "xmark")
                            .font(DesignBook.Font.footnoteBold)
                            .foregroundStyle(.white)
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
        for color in TeamDefaultColorGenerator.defaultColors {
            if !isColorUsedByOtherTeam(color) {
                teamColor = color
                return
            }
        }
    }

    var primaryButton: some View {
        Group {
            if isCreating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignBook.Color.Text.accent))
                    .scaleEffect(1.2)
                    .padding(.vertical, DesignBook.Spacing.md)
            } else {
                PrimaryButton(title: localized("createTeam.create"), icon: "plus.circle.fill") {
                    createTeam()
                }
                .disabled(!canCreate)
                .opacity(canCreate ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
            }
        }
    }

    @ToolbarContentBuilder
    var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(action: createTeam) {
                Label(localized("createTeam.create"), systemImage: "plus.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .fontWeight(.semibold)
            }
            .disabled(!canCreate)
        }
    }
}

// MARK: - Actions
private extension OnlineTeamCreationView {
    func createTeam() {
        guard canCreate else { return }
        DesignBook.Haptics.confirm()
        isCreating = true
        focusedField = nil
        let name = trimmedName
        let colorHex = teamColor.hexString

        Task {
            do {
                try await roomManager.createTeam(name: name, colorHex: colorHex)
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
