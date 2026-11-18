//
//  WordSourceView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 31.05.26.
//

import DesignBook
import Navigation
import SwiftUI

/// Fill the Hat: how many words go in and where they come from — typed by
/// the players or picked from the bundled word database. The hat at the top
/// fills with whatever the choice means (players' names or sample words),
/// and the total updates as the count changes.
struct WordSourceView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var source: WordSource = .manual
    @State private var wordsPerPlayer = GameDefaults.standard.wordsPerPlayer
    @State private var sampleWords: [String] = []
    @State private var hasLoadedConfiguration = false
    @State private var isReplaceConfirmationPresented = false

    private var playerCount: Int {
        gameManager.configuration.players.count
    }

    private var totalWords: Int {
        wordsPerPlayer * playerCount
    }

    var body: some View {
        content
            .navigationTitle(localized("wordSource.navTitle"))
            .setDefaultStyle()
            .onAppear(perform: loadConfiguration)
            .confirmationDialog(
                localized("wordSource.replaceTyped.title"),
                isPresented: $isReplaceConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(localized("wordSource.replaceTyped.confirm"), role: .destructive, action: pickForUs)
                Button(localized("common.buttons.cancel"), role: .cancel) {}
            } message: {
                Text(localized("wordSource.replaceTyped.message"))
            }
    }
}

// MARK: - Layout
private extension WordSourceView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                hero
                countCard
                sourceSection
            }
            .paddingHorizontalDefault()
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .actionBar {
            continueButton
                .paddingHorizontalDefault()
        }
    }

    var hero: some View {
        VStack(spacing: DesignBook.Spacing.xs) {
            HatFillAnimation(labels: chipLabels)
                .decorativeHeroSizing()

            HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.xs) {
                HeroNumberText(value: totalWords)
                Text(localized("wordSource.hero.unit \(totalWords)"))
                    .font(DesignBook.Font.displaySmall)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(localized("wordSource.hero.a11y \(totalWords)")))

            Text(localized("wordSource.hero.caption \(playerCount) \(wordsPerPlayer)"))
                .font(DesignBook.Font.subheadline)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
        }
    }

    var sourceSection: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            Text(localized("wordSource.question"))
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .accessibilityAddTraits(.isHeader)

            tiles
        }
    }

    /// Side by side; stacked at accessibility sizes, where half-width tiles
    /// would wrap every word.
    var tiles: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DesignBook.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DesignBook.Spacing.md))
        return layout {
            WordSourceTile(
                icon: "square.and.pencil",
                title: localized("wordSource.manual.title"),
                detail: localized("wordSource.manual.detail"),
                isSelected: source == .manual
            ) { select(.manual) }
            .accessibilityIdentifier("wordSource.manual")

            WordSourceTile(
                icon: "wand.and.stars",
                title: localized("wordSource.automatic.title"),
                detail: localized("wordSource.automatic.detail"),
                isSelected: source == .automatic
            ) { select(.automatic) }
            .accessibilityIdentifier("wordSource.automatic")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    var countCard: some View {
        GameCard {
            GameSettingsRow(
                icon: "person.fill",
                title: localized("createRoom.wordsPerPlayer"),
                value: $wordsPerPlayer.animation(
                    DesignBook.Motion.respectingReducedMotion(.snappy, reduceMotion: reduceMotion)
                ),
                range: 3...20,
                step: 1
            )
        }
    }

    var continueButton: some View {
        PrimaryButton(
            title: source == .manual
                ? localized("wordSource.continue.manual")
                : localized("wordSource.continue.automatic"),
            icon: source == .manual ? "square.and.pencil" : "wand.and.stars"
        ) {
            handleContinue()
        }
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("wordSource.continue")
    }

    /// Typed words come from the players, so the chips are their names;
    /// picked words are a taste of the word list.
    var chipLabels: [String] {
        source == .manual ? gameManager.configuration.players.map(\.name) : sampleWords
    }
}

// MARK: - Actions
private extension WordSourceView {
    /// Starts from the game's configuration, which carries the user's defaults.
    func loadConfiguration() {
        guard !hasLoadedConfiguration else { return }
        hasLoadedConfiguration = true
        source = gameManager.configuration.wordSource
        wordsPerPlayer = gameManager.configuration.wordsPerPlayer
        sampleWords = WordDatabase.randomWords(count: 12)
    }

    func select(_ newSource: WordSource) {
        withAnimation(DesignBook.Motion.respectingReducedMotion(.snappy, reduceMotion: reduceMotion)) {
            source = newSource
        }
    }

    func handleContinue() {
        gameManager.configuration.wordsPerPlayer = wordsPerPlayer
        // Words typed under a higher count would leave players over the limit.
        gameManager.trimWords(toPerPlayer: wordsPerPlayer)

        switch source {
        case .manual:
            // Picked words have no author; typing your own replaces them.
            gameManager.removePickedWords()
            gameManager.configuration.wordSource = .manual
            navigator.push(.wordInput)
        case .automatic:
            // Picking words replaces the hat, so ask first if players typed some.
            if gameManager.hasTypedWords {
                isReplaceConfirmationPresented = true
            } else {
                pickForUs()
            }
        }
    }

    func pickForUs() {
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
