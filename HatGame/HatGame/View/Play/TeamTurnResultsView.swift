//
//  TeamTurnResultsView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct TeamTurnResultsView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(GameEngine.self) private var engine
    @Environment(Navigator.self) private var navigator

    let team: Team
    let guessedWords: [Word]
    /// Guesses less skip penalties; equals the guess count without penalties.
    let points: Int
    /// Penalized skips this turn; zero when skipping costs nothing.
    let skippedCount: Int
    let completionReason: PlayCompletionReason
    @State private var isStandingsPresented = false
    @State private var hasCelebrated: Bool = false
    @State private var confettiBurst: Int = 0

    private var isCelebratory: Bool { completionReason == .allWordsGuessed }

    private var scoreUnit: String {
        skippedCount > 0
            ? localized("game.turnResults.pointsUnit \(points)")
            : localized("game.turnResults.wordsUnit \(points)")
    }

    var body: some View {
        resultsScroll
            .navigationTitle(localized("game.turnResults.title"))
            .inlineNavigationTitle()
            .setDefaultBackground()
            .toolbar {
                StandingsToolbarItem { isStandingsPresented = true }
            }
            .sheet(isPresented: $isStandingsPresented) {
                StandingsSheet()
                    .environment(gameManager)
                    .environment(engine)
                    .environment(navigator)
            }
            .onChange(of: isStandingsPresented) { _, presented in
                if !presented { confettiBurst += 1 }
            }
            .task {
                guard !hasCelebrated else { return }
                try? await Task.sleep(for: .milliseconds(120))
                hasCelebrated = true
            }
    }
}

// MARK: - Private
private extension TeamTurnResultsView {
    var resultsScroll: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                Spacer().frame(height: DesignBook.Spacing.lg)
                header
                resultsCard
                wordsSection
            }
            .paddingHorizontalDefault()
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        // Inside the action bar's content, so the confetti falls behind the button.
        .overlay {
            if isCelebratory {
                ConfettiView(isActive: hasCelebrated, retriggerId: confettiBurst)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .actionBar {
            continueButton
                .paddingHorizontalDefault()
        }
    }

    var header: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(team.color.opacity(0.12))
                    .frame(width: 104, height: 104)
                    .blur(radius: 16)

                Circle()
                    .fill(team.color.opacity(0.22))
                    .frame(width: 88, height: 88)

                Circle()
                    .strokeBorder(team.color.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 88, height: 88)

                Image(systemName: isCelebratory ? "sparkles" : "hourglass")
                    .font(DesignBook.IconFont.large)
                    .fontWeight(.bold)
                    .foregroundStyle(team.color)
                    .symbolEffect(.bounce, options: .nonRepeating, value: hasCelebrated)
            }
            .accessibilityHidden(true)
            .decorativeHeroSizing()

            Text(localized(isCelebratory ? "game.turnResults.allWordsGuessed" : "game.turnResults.timeUp"))
                .font(DesignBook.Font.displayLarge)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("turnResults.title")
        }
    }

    var resultsCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.sm) {
                Text(String(format: localized("game.turnResults.teamTitle"), team.name))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.teamText(for: team.color))
                    .multilineTextAlignment(.center)

                HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.sm) {
                    AnimatedScoreText(
                        value: points,
                        font: DesignBook.Font.heroScore,
                        color: DesignBook.Color.teamText(for: team.color),
                        duration: 0.7
                    )
                    Text(scoreUnit)
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                }
                .padding(.top, DesignBook.Spacing.xs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(points) \(scoreUnit)"))

                if skippedCount > 0 {
                    Text(localized("game.turnResults.breakdown \(guessedWords.count) \(skippedCount)"))
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    @ViewBuilder
    var wordsSection: some View {
        if guessedWords.isEmpty {
            emptyStateCard
        } else {
            guessedWordsCard
        }
    }

    var guessedWordsCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("game.turnResults.wordsGuessed"))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140))],
                    spacing: DesignBook.Spacing.sm
                ) {
                    ForEach(guessedWords) { word in
                        Text(word.text)
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                            .padding(DesignBook.Spacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(DesignBook.Color.Background.secondary)
                            .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
                    }
                }
            }
        }
    }

    var emptyStateCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: "moon.stars.fill")
                    .font(DesignBook.IconFont.large)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                Text(localized("game.turnResults.noWordsGuessed"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(DesignBook.Spacing.sm)
            .frame(maxWidth: .infinity)
        }
    }

    var continueButton: some View {
        PrimaryButton(title: localized("common.buttons.continue"), icon: "arrow.right.circle.fill") {
            engine.continueAfterTurn()
        }
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("turnResults.continue")
    }
}
