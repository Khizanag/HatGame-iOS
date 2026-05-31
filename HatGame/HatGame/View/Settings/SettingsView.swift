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
        ScrollView {
            VStack(spacing: DesignBook.Spacing.xl) {
                appearanceSection
                gameDefaultsSection
                accessibilitySection
                aboutSection
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .navigationTitle(String(localized: "settings.title"))
        .setDefaultStyle()
    }
}

// MARK: - Subviews
private extension SettingsView {
    var appearanceSection: some View {
        SettingsSection(
            title: String(localized: "settings.appearance.title"),
            footer: String(localized: "settings.appearance.description")
        ) {
            VStack(spacing: DesignBook.Spacing.md) {
                ColorSchemePickerCard(
                    selection: Binding(
                        get: { appConfiguration.colorScheme },
                        set: { appConfiguration.colorScheme = $0 }
                    )
                )
                Button {
                    DesignBook.Haptics.selection()
                    navigator.push(.appIconSelection)
                } label: {
                    SettingsRow(
                        icon: "app.gift.fill",
                        title: String(localized: "settings.appIcon.title"),
                        subtitle: appConfiguration.appIcon.title
                    )
                }
                .buttonStyle(.plain)
                .navigationZoomSource(id: "appIconSelection", in: zoomNamespace)
            }
        }
    }

    var gameDefaultsSection: some View {
        SettingsSection(
            title: String(localized: "settings.defaults.sectionTitle"),
            footer: String(localized: "settings.defaults.description")
        ) {
            Button {
                DesignBook.Haptics.selection()
                navigator.push(.defaultsSettings)
            } label: {
                SettingsRow(
                    icon: "slider.horizontal.3",
                    iconColor: .orange,
                    title: String(localized: "settings.defaults.title"),
                    subtitle: defaultsSummary
                )
            }
            .buttonStyle(.plain)
        }
    }

    var accessibilitySection: some View {
        SettingsSection(
            title: String(localized: "settings.accessibility.title"),
            footer: String(localized: "settings.handedness.description")
        ) {
            HandednessPickerCard(
                selection: Binding(
                    get: { appConfiguration.isRightHanded ? .right : .left },
                    set: { appConfiguration.isRightHanded = ($0 == .right) }
                )
            )
        }
    }

    var aboutSection: some View {
        SettingsSection(title: String(localized: "settings.about.sectionTitle")) {
            VStack(spacing: DesignBook.Spacing.sm) {
                Button {
                    DesignBook.Haptics.selection()
                    navigator.push(.developerInfo)
                } label: {
                    SettingsRow(
                        icon: "person.circle.fill",
                        iconColor: .purple,
                        title: String(localized: "settings.developerInfo.title"),
                        subtitle: String(localized: "settings.developerInfo.description")
                    )
                }
                .buttonStyle(.plain)

                FeedbackRow()
                AppInfoRows()
            }
        }
    }

    var defaultsSummary: String {
        String(
            format: "%d words • %d seconds",
            appConfiguration.defaultWordsPerPlayer,
            appConfiguration.defaultRoundDuration
        )
    }
}

// MARK: - Subview types
private struct ColorSchemePickerCard: View {
    @Binding var selection: AppColorScheme

    var body: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            SettingsCardHeader(icon: "paintbrush.fill", title: "settings.appearance.colorScheme")
            SegmentedSelectionView(items: items, selection: $selection)
        }
        .padding(DesignBook.Spacing.md)
        .background(DesignBook.Color.Background.card)
        .cornerRadius(DesignBook.Size.cardCornerRadius)
    }

    private var items: [SegmentedSelectionItem<AppColorScheme>] {
        [
            SegmentedSelectionItem(
                id: .light,
                title: String(localized: "settings.appearance.light"),
                subtitle: nil,
                icon: Image(systemName: "sun.max.fill")
            ),
            SegmentedSelectionItem(
                id: .dark,
                title: String(localized: "settings.appearance.dark"),
                subtitle: nil,
                icon: Image(systemName: "moon.fill")
            ),
            SegmentedSelectionItem(
                id: .system,
                title: String(localized: "settings.appearance.system"),
                subtitle: "settings.appearance.auto",
                icon: Image(systemName: "circle.lefthalf.filled")
            ),
        ]
    }
}

private struct HandednessPickerCard: View {
    @Binding var selection: Handedness

    var body: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            SettingsCardHeader(icon: "hand.raised.fill", title: "settings.handedness.title")
            SegmentedSelectionView(items: items, selection: $selection)
        }
        .padding(DesignBook.Spacing.md)
        .background(DesignBook.Color.Background.card)
        .cornerRadius(DesignBook.Size.cardCornerRadius)
    }

    private var items: [SegmentedSelectionItem<Handedness>] {
        [
            SegmentedSelectionItem(
                id: .left,
                title: String(localized: "settings.handedness.left"),
                subtitle: nil,
                icon: Image(systemName: "hand.point.left.fill")
            ),
            SegmentedSelectionItem(
                id: .right,
                title: String(localized: "settings.handedness.right"),
                subtitle: nil,
                icon: Image(systemName: "hand.point.right.fill")
            ),
        ]
    }
}

private struct SettingsCardHeader: View {
    let icon: String
    let title: LocalizedStringKey

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.accent)

            Text(title)
                .font(DesignBook.Font.headline)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Spacer()
        }
    }
}

private struct FeedbackRow: View {
    private static let mailtoURL = URL(string: "mailto:giga.khizanishvili@gmail.com?subject=Hat%20Game%20Feedback")

    var body: some View {
        Group {
            if let mailtoURL = Self.mailtoURL {
                Link(destination: mailtoURL) {
                    SettingsRow(
                        icon: "envelope.fill",
                        iconColor: .blue,
                        title: String(localized: "settings.feedback.title"),
                        subtitle: String(localized: "settings.feedback.description")
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AppInfoRows: View {
    var body: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            if let version = appVersion {
                SettingsRow(
                    icon: "number",
                    iconColor: .blue,
                    title: String(localized: "settings.about.version"),
                    subtitle: version,
                    showChevron: false
                ) {
                    EmptyView()
                }
            }

            if let build = appBuild {
                SettingsRow(
                    icon: "wrench.and.screwdriver",
                    iconColor: .green,
                    title: String(localized: "settings.about.build"),
                    subtitle: build,
                    showChevron: false
                ) {
                    EmptyView()
                }
            }
        }
    }

    private var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private var appBuild: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(Navigator())
}
