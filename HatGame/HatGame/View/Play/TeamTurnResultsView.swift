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
    @Environment(Navigator.self) private var navigator

    let guessedWords: [Word]
    let completionReason: PlayCompletionReason
    @State private var isStandingsPresented = false
    @State private var hasCelebrated: Bool = false

    private var isCelebratory: Bool { completionReason == .allWordsGuessed }

    var body: some View {
        resultsScroll
            .setDefaultBackground()
            .navigationBarBackButtonHidden()
            .overlay {
                if isCelebratory {
                    ConfettiView(isActive: hasCelebrated)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .sheet(isPresented: $isStandingsPresented) {
                NavigationStack {
                    ResultsView()
                }
                .environment(gameManager)
                .environment(navigator)
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
        .safeAreaInset(edge: .bottom) {
            buttonsSection
                .paddingHorizontalDefault()
                .withFooterGradient()
        }
    }

    var header: some View {
        let team = gameManager.currentTeam
        return VStack(spacing: DesignBook.Spacing.sm) {
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
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(team.color)
                    .symbolEffect(.bounce, options: .nonRepeating, value: hasCelebrated)
            }
            .accessibilityHidden(true)

            Text(isCelebratory ? "game.turnResults.allWordsGuessed" : "game.turnResults.timeUp")
                .font(DesignBook.Font.largeTitle)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
        }
    }

    var resultsCard: some View {
        let team = gameManager.currentTeam
        return GameCard {
            VStack(spacing: DesignBook.Spacing.sm) {
                Text(String(format: String(localized: "game.turnResults.teamTitle"), team.name))
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(team.color)
                    .multilineTextAlignment(.center)

                HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.sm) {
                    AnimatedScoreText(
                        value: guessedWords.count,
                        font: .system(size: 64, weight: .bold, design: .rounded),
                        color: team.color,
                        duration: 0.7
                    )
                    Text("game.turnResults.wordsUnit")
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                }
                .padding(.top, DesignBook.Spacing.xs)
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
                Text("game.turnResults.wordsGuessed")
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: DesignBook.Spacing.sm
                ) {
                    ForEach(guessedWords) { word in
                        Text(word.text)
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                            .padding(DesignBook.Spacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(DesignBook.Color.Background.secondary)
                            .cornerRadius(DesignBook.Size.smallCardCornerRadius)
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
                Text("game.turnResults.noWordsGuessed")
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(DesignBook.Spacing.sm)
            .frame(maxWidth: .infinity)
        }
    }

    var buttonsSection: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            SecondaryButton(title: String(localized: "game.turnResults.checkStandings"), icon: "list.bullet.rectangle") {
                DesignBook.Haptics.tap()
                isStandingsPresented = true
            }

            PrimaryButton(title: String(localized: "common.buttons.continue"), icon: "arrow.right.circle.fill") {
                DesignBook.Haptics.tap()
                gameManager.prepareForNewPlay()

                if let round = gameManager.currentRound {
                    navigator.push(
                        .nextTeam(
                            round: round,
                            team: gameManager.currentTeam
                        )
                    )
                } else {
                    navigator.push(.finalResults)
                }
            }
        }
    }
}
