//
//  RoomSetupForm.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import Networking
import SwiftUI

/// The host's room form shared by online and nearby play: a hero, the
/// player's name, the game settings, and a create button pinned to the
/// bottom — above the keyboard while typing — that stays disabled until a
/// name is entered.
struct RoomSetupForm<Hero: View>: View {
    private enum Field: Hashable { case name }

    @Binding var playerName: String
    @Binding var settings: GameSettings
    let actionTitle: String
    let actionIcon: String
    let isWorking: Bool
    let action: () -> Void
    @ViewBuilder let hero: Hero

    @FocusState private var focusedField: Field?

    private var canSubmit: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                hero
                PlayerNameCard(
                    title: localized("createRoom.yourName"),
                    placeholder: localized("createRoom.enterName"),
                    name: $playerName,
                    focus: $focusedField,
                    field: .name,
                    onSubmit: submit
                )
                settingsCard
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            submitButton
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.md)
                .padding(.bottom, DesignBook.Spacing.sm)
                .withFooterGradient()
        }
        .onAppear { focusedField = .name }
    }
}

// MARK: - Composition
private extension RoomSetupForm {
    var settingsCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.lg) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "gearshape.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text(localized("createRoom.gameSettings"))
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
                VStack(spacing: DesignBook.Spacing.md) {
                    settingsRows
                }
            }
        }
    }

    @ViewBuilder
    var settingsRows: some View {
        GameSettingsRow(
            icon: "text.bubble.fill",
            title: localized("createRoom.wordsPerPlayer"),
            value: $settings.wordsPerPlayer,
            range: 3...10,
            step: 1
        )
        GameSettingsRow(
            icon: "timer",
            title: localized("createRoom.roundDuration"),
            value: $settings.roundDuration,
            range: 30...120,
            step: 10,
            suffix: localized("createRoom.seconds")
        )
        GameSettingsToggleRow(
            icon: "wand.and.stars",
            title: localized("wordSource.automatic.title"),
            subtitle: localized("wordSource.automatic.description"),
            isOn: $settings.isAutomaticWords
        )
        GameSettingsToggleRow(
            icon: "arrow.uturn.forward",
            title: localized("timerSettings.allowSkipping.title"),
            subtitle: localized("timerSettings.allowSkipping.description"),
            isOn: $settings.isSkippingEnabled,
            tint: DesignBook.Color.Status.warning
        )
    }

    var submitButton: some View {
        Group {
            if isWorking {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignBook.Color.Text.accent))
                    .scaleEffect(1.2)
                    .padding(.vertical, DesignBook.Spacing.md)
            } else {
                PrimaryButton(title: actionTitle, icon: actionIcon, action: submit)
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    func submit() {
        guard canSubmit else { return }
        focusedField = nil
        action()
    }
}
