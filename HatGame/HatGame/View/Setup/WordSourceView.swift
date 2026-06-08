//
//  WordSourceView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 31.05.26.
//

import DesignBook
import Navigation
import SwiftUI

/// Lets the host choose where the game's words come from: typed in by the
/// players (manual) or picked automatically from the bundled word database.
struct WordSourceView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator

    var body: some View {
        content
            .navigationTitle(localized("wordSource.navTitle"))
            .setDefaultStyle()
    }
}

// MARK: - Layout
private extension WordSourceView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                HeaderCard(
                    title: localized("wordSource.question"),
                    description: localized("wordSource.description")
                )

                optionCard(
                    icon: "square.and.pencil",
                    title: localized("wordSource.manual.title"),
                    description: localized("wordSource.manual.description"),
                    action: chooseManual
                )

                optionCard(
                    icon: "wand.and.stars",
                    title: localized("wordSource.automatic.title"),
                    description: localized("wordSource.automatic.description"),
                    action: chooseAutomatic
                )
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
    }

    func optionCard(
        icon: String,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            GameCard {
                HStack(spacing: DesignBook.Spacing.md) {
                    CircularIconContainer(
                        icon: icon,
                        size: DesignBook.Size.cardSmall,
                        iconSize: DesignBook.Size.iconSize,
                        color: DesignBook.Color.Text.accent,
                        backgroundColor: DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.light)
                    )

                    VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                        Text(title)
                            .font(DesignBook.Font.headline)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                        Text(description)
                            .font(DesignBook.Font.caption)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: DesignBook.Spacing.sm)

                    Image(systemName: "chevron.right")
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(description))
    }
}

// MARK: - Actions
private extension WordSourceView {
    func chooseManual() {
        DesignBook.Haptics.tap()
        gameManager.configuration.wordSource = .manual
        navigator.push(.wordInput)
    }

    func chooseAutomatic() {
        DesignBook.Haptics.tap()
        gameManager.configuration.wordSource = .automatic
        navigator.push(.wordGeneration)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        WordSourceView()
    }
    .environment(Navigator())
    .environment(GameManager())
}
