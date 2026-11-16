//
//  DeveloperInfoView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

struct DeveloperInfoView: View {
    private let appConfiguration = AppConfiguration.shared

    var body: some View {
        Form {
            aboutSection
            technologiesSection
            contactSection
            creditsSection
            #if DEBUG
            testModeSection
            #endif
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(localized("settings.developerInfo.title"))
        .setDefaultStyle()
    }
}

// MARK: - Sections
private extension DeveloperInfoView {
    var aboutSection: some View {
        Section {
            Text(localized("settings.developerInfo.about.description"))
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
        } header: {
            Text(localized("settings.developerInfo.about.title"))
        } footer: {
            Text(localized("settings.developerInfo.createdBy"))
        }
    }

    var technologiesSection: some View {
        Section {
            technologyRow("settings.technologies.swiftui", icon: "swift", tint: .orange)
            technologyRow("settings.technologies.navigation", icon: "arrow.triangle.branch", tint: .blue)
            technologyRow("settings.technologies.designbook", icon: "paintpalette.fill", tint: .purple)
        } header: {
            Text(localized("settings.developerInfo.technologies.title"))
        }
    }

    var contactSection: some View {
        Section {
            linkRow(
                destination: URL(string: "https://github.com/gigakhizanishvili")!,
                icon: "link",
                tint: .green,
                title: "GitHub: @gigakhizanishvili"
            )
        } header: {
            Text(localized("settings.developerInfo.contact.title"))
        } footer: {
            Text(localized("settings.developerInfo.contact.message"))
        }
    }

    var creditsSection: some View {
        Section {
            HStack(spacing: DesignBook.Spacing.md) {
                SettingsIconTile(systemImage: "person.fill", tint: .indigo)
                titleStack(
                    title: localized("home.director.name"),
                    subtitle: localized("settings.developerInfo.credits.rulesExplainer")
                )
            }
            .accessibilityElement(children: .combine)

            linkRow(
                destination: URL(string: "https://en.wiktionary.org/wiki/Category:Georgian_nouns")!,
                icon: "text.book.closed.fill",
                tint: .brown,
                title: localized("settings.developerInfo.credits.words"),
                subtitle: localized("settings.developerInfo.credits.wordsLicense")
            )
        } header: {
            Text(localized("settings.developerInfo.credits.title"))
        }
    }

    #if DEBUG
    var testModeSection: some View {
        Section {
            SettingsToggleRow(
                icon: appConfiguration.isTestMode ? "wrench.adjustable.fill" : "wrench.adjustable",
                title: localized("settings.testMode.title"),
                isOn: Binding(
                    get: { appConfiguration.isTestMode },
                    set: { appConfiguration.isTestMode = $0 }
                )
            )
        } footer: {
            Text(localized("settings.testMode.description"))
        }
    }
    #endif
}

// MARK: - Rows
private extension DeveloperInfoView {
    func technologyRow(_ text: String.LocalizationValue, icon: String, tint: Color) -> some View {
        HStack(spacing: DesignBook.Spacing.md) {
            SettingsIconTile(systemImage: icon, tint: tint)
            Text(localized(text))
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
        }
    }

    /// An external link: opens Safari, marked with the arrow that leaves
    /// the app.
    func linkRow(
        destination: URL,
        icon: String,
        tint: Color,
        title: String,
        subtitle: String? = nil
    ) -> some View {
        Link(destination: destination) {
            HStack(spacing: DesignBook.Spacing.md) {
                SettingsIconTile(systemImage: icon, tint: tint)
                titleStack(title: title, subtitle: subtitle)
                Spacer(minLength: DesignBook.Spacing.sm)
                Image(systemName: "arrow.up.right")
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    func titleStack(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
            Text(title)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
            if let subtitle {
                Text(subtitle)
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DeveloperInfoView()
    }
    .environment(GameManager())
}
