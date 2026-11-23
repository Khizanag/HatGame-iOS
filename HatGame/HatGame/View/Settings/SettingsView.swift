//
//  SettingsView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct SettingsView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(\.navZoomNamespace) private var zoomNamespace

    private let appConfiguration = AppConfiguration.shared

    var body: some View {
        Form {
            appearanceSection
            languageSection
            gameDefaultsSection
            accessibilitySection
            aboutSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(localized("settings.title"))
        .setDefaultStyle(titleDisplay: .large)
    }
}

// MARK: - Sections
private extension SettingsView {
    var appearanceSection: some View {
        Section {
            themeRow
            #if os(iOS)
            // Alternate app icons are an iOS-only capability; the picker would
            // be a no-op on macOS.
            appIconRow
            #endif
        } header: {
            Text(localized("settings.appearance.title"))
        } footer: {
            Text(localized("settings.appearance.description"))
        }
    }

    var languageSection: some View {
        Section {
            languageRow
        } header: {
            Text(localized("settings.language.title"))
        } footer: {
            Text(localized("settings.language.description"))
        }
    }

    var gameDefaultsSection: some View {
        Section {
            SettingsLinkRow(
                icon: "slider.horizontal.3",
                tint: .orange,
                title: localized("settings.defaults.title")
            ) {
                navigator.push(.defaultsSettings)
            }
        } header: {
            Text(localized("settings.defaults.sectionTitle"))
        } footer: {
            Text(localized("settings.defaults.description"))
        }
    }

    var accessibilitySection: some View {
        Section {
            handednessRow
        } header: {
            Text(localized("settings.accessibility.title"))
        } footer: {
            Text(localized("settings.handedness.description"))
        }
    }

    var aboutSection: some View {
        Section {
            SettingsLinkRow(
                icon: "person.circle.fill",
                tint: .purple,
                title: localized("settings.developerInfo.title")
            ) {
                navigator.push(.developerInfo)
            }

            SettingsLinkRow(
                icon: "envelope.fill",
                tint: .blue,
                title: localized("settings.feedback.title")
            ) {
                navigator.push(.feedback)
            }

            if let appVersion {
                infoRow(icon: "number", tint: .blue, title: localized("settings.about.version"), value: appVersion)
            }

            if let appBuild {
                infoRow(
                    icon: "wrench.and.screwdriver",
                    tint: .green,
                    title: localized("settings.about.build"),
                    value: appBuild
                )
            }
        } header: {
            Text(localized("settings.about.sectionTitle"))
        }
    }
}

// MARK: - Rows
private extension SettingsView {
    var themeRow: some View {
        SettingsPickerRow(
            icon: "paintbrush.fill",
            title: localized("settings.appearance.colorScheme"),
            value: appConfiguration.colorScheme.displayName,
            valueSystemImage: appConfiguration.colorScheme.systemImage,
            selection: colorSchemeBinding
        ) {
            ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                Label(scheme.displayName, systemImage: scheme.systemImage).tag(scheme)
            }
        }
    }

    var appIconRow: some View {
        SettingsLinkRow(
            icon: "app.gift.fill",
            title: localized("settings.appIcon.title"),
            value: appConfiguration.appIcon.title
        ) {
            navigator.push(.appIconSelection)
        }
        .navigationZoomSource(id: "appIconSelection", in: zoomNamespace)
    }

    var languageRow: some View {
        SettingsPickerRow(
            icon: "globe",
            title: localized("settings.language.title"),
            value: appConfiguration.language.displayName,
            valueSystemImage: appConfiguration.language.systemImage,
            selection: languageBinding
        ) {
            ForEach(AppLanguage.allCases) { language in
                Label(language.displayName, systemImage: language.systemImage).tag(language)
            }
        }
    }

    var handednessRow: some View {
        SettingsPickerRow(
            icon: "hand.raised.fill",
            title: localized("settings.handedness.title"),
            value: handedness.displayName,
            valueSystemImage: handedness.systemImage,
            selection: handednessBinding
        ) {
            ForEach(Handedness.allCases, id: \.self) { hand in
                Label(hand.displayName, systemImage: hand.systemImage).tag(hand)
            }
        }
    }

    func infoRow(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: DesignBook.Spacing.md) {
            SettingsIconTile(systemImage: icon, tint: tint)

            Text(title)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Spacer(minLength: DesignBook.Spacing.sm)

            Text(value)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Derived state
private extension SettingsView {
    var handedness: Handedness {
        appConfiguration.isRightHanded ? .right : .left
    }

    var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var appBuild: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    var colorSchemeBinding: Binding<AppColorScheme> {
        Binding(
            get: { appConfiguration.colorScheme },
            set: {
                appConfiguration.colorScheme = $0
            }
        )
    }

    var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { appConfiguration.language },
            set: {
                appConfiguration.language = $0
            }
        )
    }

    var handednessBinding: Binding<Handedness> {
        Binding(
            get: { handedness },
            set: {
                appConfiguration.isRightHanded = ($0 == .right)
            }
        )
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(Navigator())
}
