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
        List {
            wordsSection
            durationSection
            duplicatesSection
            skippingSection
            soundSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(localized("settings.defaults.title"))
        .setDefaultStyle()
    }
}

// MARK: - Sections
private extension DefaultsSettingsView {
    var wordsSection: some View {
        Section {
            GameSettingsRow(
                icon: "text.bubble.fill",
                title: localized("settings.defaultWordsPerPlayer.title"),
                value: wordsBinding,
                range: 3...20,
                step: 1
            )
        } footer: {
            Text(localized("settings.defaultWordsPerPlayer.description"))
        }
    }

    var durationSection: some View {
        Section {
            GameSettingsRow(
                icon: "timer.circle.fill",
                title: localized("settings.defaultRoundDuration.title"),
                value: durationBinding,
                range: 5...120,
                step: 5,
                suffix: localized("createRoom.seconds")
            )
        } footer: {
            Text(localized("settings.defaultRoundDuration.description"))
        }
    }

    var duplicatesSection: some View {
        Section {
            SettingsToggleRow(
                icon: "doc.on.doc.fill",
                tint: .purple,
                title: localized("settings.allowDuplicateWords.title"),
                isOn: duplicatesBinding
            )
        } footer: {
            Text(localized("settings.allowDuplicateWords.description"))
        }
    }

    var skippingSection: some View {
        Section {
            SettingsToggleRow(
                icon: "arrow.uturn.forward",
                tint: .orange,
                title: localized("settings.defaultSkipping.title"),
                isOn: skippingBinding
            )
        } footer: {
            Text(localized("settings.defaultSkipping.description"))
        }
    }

    var soundSection: some View {
        Section {
            SettingsToggleRow(
                icon: "speaker.wave.2.fill",
                tint: .green,
                title: localized("settings.timeUpSound.title"),
                isOn: soundBinding
            )
        } footer: {
            Text(localized("settings.timeUpSound.description"))
        }
    }
}

// MARK: - Bindings
private extension DefaultsSettingsView {
    var wordsBinding: Binding<Int> {
        Binding(
            get: { appConfiguration.defaultWordsPerPlayer },
            set: { appConfiguration.defaultWordsPerPlayer = $0 }
        )
    }

    var durationBinding: Binding<Int> {
        Binding(
            get: { appConfiguration.defaultRoundDuration },
            set: { appConfiguration.defaultRoundDuration = $0 }
        )
    }

    var duplicatesBinding: Binding<Bool> {
        Binding(
            get: { appConfiguration.allowDuplicateWords },
            set: { appConfiguration.allowDuplicateWords = $0 }
        )
    }

    var skippingBinding: Binding<Bool> {
        Binding(
            get: { appConfiguration.defaultSkippingEnabled },
            set: { appConfiguration.defaultSkippingEnabled = $0 }
        )
    }

    var soundBinding: Binding<Bool> {
        Binding(
            get: { appConfiguration.isTimeUpSoundEnabled },
            set: { appConfiguration.isTimeUpSoundEnabled = $0 }
        )
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DefaultsSettingsView()
    }
}
