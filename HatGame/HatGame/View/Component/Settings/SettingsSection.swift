//
//  SettingsSection.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 26.11.25.
//

import DesignBook
import SwiftUI

/// A reusable section component for organizing settings
struct SettingsSection<Content: View>: View {
    let title: String?
    let footer: String?
    let content: () -> Content

    init(
        title: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            if let title {
                sectionHeader(title)
            }

            VStack(spacing: DesignBook.Spacing.sm) {
                content()
            }

            if let footer {
                sectionFooter(footer)
            }
        }
    }
}

// MARK: - Subviews
private extension SettingsSection {
    func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(DesignBook.Font.caption)
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.bottom, DesignBook.Spacing.xs)
    }

    func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(DesignBook.Font.caption)
            .foregroundStyle(DesignBook.Color.Text.tertiary)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.top, DesignBook.Spacing.xs)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: DesignBook.Spacing.xl) {
            SettingsSection(
                title: "Appearance",
                footer: "Customize the look and feel of the app"
            ) {
                Label("Theme", systemImage: "paintbrush")
                Label("App Icon", systemImage: "app.gift.fill")
            }

            SettingsSection(title: "Game Defaults") {
                Label("Words per Player", systemImage: "text.bubble")
                Label("Round Duration", systemImage: "timer")
            }
        }
        .paddingHorizontalDefault()
        .padding(.top, DesignBook.Spacing.lg)
    }
    .setDefaultBackground()
}
