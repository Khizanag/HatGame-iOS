//
//  DefaultsSettingsView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct DefaultsSettingsView: View {
    private let appConfiguration = AppConfiguration.shared

    var body: some View {
        content
            .navigationTitle(String(localized: "settings.defaults.title"))
            .setDefaultStyle()
    }
}

// MARK: - Private
private extension DefaultsSettingsView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.xl) {
                descriptionText
                wordsPerPlayerSection
                roundDurationSection
                duplicateWordsSection
                skippingSection
                soundSection
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
    }

    var descriptionText: some View {
        Text("settings.defaults.description")
            .font(DesignBook.Font.body)
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .padding(.horizontal, DesignBook.Spacing.sm)
    }

    // MARK: - Words Per Player
    var wordsPerPlayerSection: some View {
        SettingsSection(
            title: String(localized: "settings.defaultWordsPerPlayer.title"),
            footer: String(localized: "settings.defaultWordsPerPlayer.description")
        ) {
            GameSettingsRow(
                icon: "text.bubble.fill",
                title: String(localized: "settings.defaultWordsPerPlayer.title"),
                value: Binding(
                    get: { appConfiguration.defaultWordsPerPlayer },
                    set: { appConfiguration.defaultWordsPerPlayer = $0 }
                ),
                range: 3...20,
                step: 1
            )
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }

    // MARK: - Round Duration
    var roundDurationSection: some View {
        SettingsSection(
            title: String(localized: "settings.defaultRoundDuration.title"),
            footer: String(localized: "settings.defaultRoundDuration.description")
        ) {
            GameSettingsRow(
                icon: "timer.circle.fill",
                title: String(localized: "settings.defaultRoundDuration.title"),
                value: Binding(
                    get: { appConfiguration.defaultRoundDuration },
                    set: { appConfiguration.defaultRoundDuration = $0 }
                ),
                range: 5...120,
                step: 5,
                suffix: String(localized: "createRoom.seconds")
            )
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }

    // MARK: - Duplicate Words
    var duplicateWordsSection: some View {
        SettingsSection(
            title: String(localized: "settings.allowDuplicateWords.title"),
            footer: String(localized: "settings.allowDuplicateWords.description")
        ) {
            VStack(spacing: DesignBook.Spacing.md) {
                Toggle(isOn: Binding(
                    get: { appConfiguration.allowDuplicateWords },
                    set: { appConfiguration.allowDuplicateWords = $0 }
                )) {
                    HStack(spacing: DesignBook.Spacing.sm) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(DesignBook.Font.body)
                            .foregroundStyle(.purple)

                        Text("settings.allowDuplicateWords.title")
                            .font(DesignBook.Font.headline)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                    }
                }
                .tint(.purple)
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }

    // MARK: - Skipping
    var skippingSection: some View {
        SettingsSection(
            title: String(localized: "settings.defaultSkipping.title"),
            footer: String(localized: "settings.defaultSkipping.description")
        ) {
            VStack(spacing: DesignBook.Spacing.md) {
                Toggle(isOn: Binding(
                    get: { appConfiguration.defaultSkippingEnabled },
                    set: { appConfiguration.defaultSkippingEnabled = $0 }
                )) {
                    HStack(spacing: DesignBook.Spacing.sm) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(DesignBook.Font.body)
                            .foregroundStyle(.orange)

                        Text("settings.defaultSkipping.title")
                            .font(DesignBook.Font.headline)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                    }
                }
                .tint(.orange)
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }

    // MARK: - Time's Up Sound
    var soundSection: some View {
        SettingsSection(
            title: String(localized: "settings.timeUpSound.title"),
            footer: String(localized: "settings.timeUpSound.description")
        ) {
            VStack(spacing: DesignBook.Spacing.md) {
                Toggle(isOn: Binding(
                    get: { appConfiguration.isTimeUpSoundEnabled },
                    set: { appConfiguration.isTimeUpSoundEnabled = $0 }
                )) {
                    HStack(spacing: DesignBook.Spacing.sm) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(DesignBook.Font.body)
                            .foregroundStyle(.green)

                        Text("settings.timeUpSound.title")
                            .font(DesignBook.Font.headline)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                    }
                }
                .tint(.green)
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DefaultsSettingsView()
    }
}
