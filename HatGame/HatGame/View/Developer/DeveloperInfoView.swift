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
        ScrollView {
            VStack(spacing: DesignBook.Spacing.xl) {
                headerText
                aboutSection
                technologiesSection
                contactSection
                creditsSection
                testModeSection
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .navigationTitle(localized("settings.developerInfo.title"))
        .setDefaultStyle()
    }
}

// MARK: - Private
private extension DeveloperInfoView {
    var headerText: some View {
        Text(localized("settings.developerInfo.createdBy"))
            .font(DesignBook.Font.body)
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .padding(.horizontal, DesignBook.Spacing.sm)
    }

    // MARK: - Credits Section
    var creditsSection: some View {
        SettingsSection(
            title: localized("settings.developerInfo.credits.title")
        ) {
            VStack(spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "person.2.circle.fill")
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.accent)

                    Text(localized("settings.developerInfo.credits.title"))
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Spacer()
                }

                HStack(alignment: .center, spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "person.fill")
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.accent)

                    VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                        Text(localized("home.director.name"))
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.primary)

                        Text(localized("settings.developerInfo.credits.rulesExplainer"))
                            .font(DesignBook.Font.caption)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                    }

                    Spacer()
                }

                Link(destination: URL(string: "https://en.wiktionary.org/wiki/Category:Georgian_nouns")!) {
                    HStack(alignment: .center, spacing: DesignBook.Spacing.sm) {
                        Image(systemName: "text.book.closed.fill")
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.accent)

                        VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                            Text(localized("settings.developerInfo.credits.words"))
                                .font(DesignBook.Font.body)
                                .foregroundStyle(DesignBook.Color.Text.primary)

                            Text(localized("settings.developerInfo.credits.wordsLicense"))
                                .font(DesignBook.Font.caption)
                                .foregroundStyle(DesignBook.Color.Text.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(DesignBook.Font.caption)
                            .foregroundStyle(DesignBook.Color.Text.accent)
                    }
                }
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }

    // MARK: - About Section
    var aboutSection: some View {
        SettingsSection(
            title: localized("settings.developerInfo.about.title")
        ) {
            VStack(spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "person.circle.fill")
                        .font(DesignBook.Font.body)
                        .foregroundStyle(.purple)

                    Text(localized("settings.developerInfo.about.title"))
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Spacer()
                }

                Text(localized("settings.developerInfo.about.description"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }

    // MARK: - Technologies Section
    var technologiesSection: some View {
        SettingsSection(
            title: localized("settings.developerInfo.technologies.title")
        ) {
            VStack(spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "hammer.circle.fill")
                        .font(DesignBook.Font.body)
                        .foregroundStyle(.blue)

                    Text(localized("settings.developerInfo.technologies.title"))
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
                    techBullet("settings.technologies.swiftui")
                    techBullet("settings.technologies.navigation")
                    techBullet("settings.technologies.designbook")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }

    func techBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignBook.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(DesignBook.Font.caption)
                .foregroundStyle(.blue)
                .padding(.top, 2)

            Text(LocalizedStringKey(text))
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
    }

    // MARK: - Test Mode Section
    var testModeSection: some View {
        SettingsSection(
            title: localized("settings.testMode.title"),
            footer: localized("settings.testMode.description")
        ) {
            VStack(spacing: DesignBook.Spacing.md) {
                Toggle(isOn: Binding(
                    get: { appConfiguration.isTestMode },
                    set: { appConfiguration.isTestMode = $0 }
                )) {
                    HStack(spacing: DesignBook.Spacing.sm) {
                        Image(systemName: appConfiguration.isTestMode ? "wrench.adjustable.fill" : "wrench.adjustable")
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.accent)
                            .contentTransition(.symbolEffect(.replace))

                        Text(localized("settings.testMode.title"))
                            .font(DesignBook.Font.headline)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                    }
                }
                .tint(DesignBook.Color.Text.accent)
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }

    // MARK: - Contact Section
    var contactSection: some View {
        SettingsSection(
            title: localized("settings.developerInfo.contact.title")
        ) {
            VStack(spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "envelope.circle.fill")
                        .font(DesignBook.Font.body)
                        .foregroundStyle(.green)

                    Text(localized("settings.developerInfo.contact.title"))
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                    Text(localized("settings.developerInfo.contact.message"))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Link(destination: URL(string: "https://github.com/gigakhizanishvili")!) {
                        HStack(spacing: DesignBook.Spacing.sm) {
                            Image(systemName: "link.circle.fill")
                                .font(DesignBook.Font.body)
                                .foregroundStyle(.green)

                            Text("GitHub: @gigakhizanishvili")
                                .font(DesignBook.Font.body)
                                .foregroundStyle(.green)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(DesignBook.Font.caption)
                                .foregroundStyle(.green)
                        }
                        .padding(DesignBook.Spacing.sm)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                    }
                }
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperInfoView()
    }
    .environment(GameManager())
}
