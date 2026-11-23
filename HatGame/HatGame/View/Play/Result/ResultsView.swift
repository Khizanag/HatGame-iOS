//
//  ResultsView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct ResultsView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(GameEngine.self) private var engine
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isTotalScoresExpanded = false
    @State private var expandedRounds: Set<GameRound> = []
    @State private var hasCelebrated = false
    /// The final actions stay off for a moment after Game Over appears, so a
    /// second Return or tap meant for the last turn's Continue can't start a
    /// rematch and wipe the scores before anyone sees them.
    @State private var areFinalActionsArmed = false

    private var isFinal: Bool { engine.phase == .finished }
    private var scoreboard: Scoreboard { engine.scoreboard }
    private var winners: [Team] { scoreboard.winners }

    var body: some View {
        content
            .navigationTitle(
                localized(isFinal ? "game.results.gameOverTitle" : "game.standings.title")
            )
            .setDefaultStyle()
            .onAppear(perform: handleAppear)
            .task {
                guard isFinal else { return }
                try? await Task.sleep(for: DesignBook.Motion.celebrationDelay)
                hasCelebrated = true
                announceWinners()
                try? await Task.sleep(for: .milliseconds(420))
                areFinalActionsArmed = true
            }
    }
}

// MARK: - Announcement
private extension ResultsView {
    /// Says who won, since the result is the change a VoiceOver user waits
    /// for (constitution article 18).
    func announceWinners() {
        guard let first = winners.first else { return }
        let message = winners.count == 1
            ? localized("game.results.winnerAnnouncement \(first.name)")
            : localized("game.results.tieAnnouncement")
        AccessibilityNotification.Announcement(message).post()
    }
}

// MARK: - Composition
private extension ResultsView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.xl) {
                winnerSection

                if isFinal {
                    allRoundsSection
                    totalScoresSection
                } else {
                    totalScoresSection
                    allRoundsSection
                }
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        // Inside the action bar's content, so the confetti falls behind the buttons.
        .overlay(alignment: .top) {
            if isFinal {
                ConfettiView(isActive: hasCelebrated)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .actionBar {
            actionSection
                .paddingHorizontalDefault()
        }
    }

    @ViewBuilder
    var winnerSection: some View {
        if isFinal {
            winnerCard
        }
    }

    var winnerCard: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            trophyIcon
                .decorativeHeroSizing()

            if winners.count == 1, let winner = winners.first {
                singleWinnerLabel(winner: winner)
            } else {
                multipleWinnersLabel
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignBook.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                .fill(DesignBook.Color.Background.card)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                        .fill(DesignBook.Gradient.celebration.opacity(DesignBook.Opacity.medium))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                        .strokeBorder(DesignBook.Gradient.celebrationRim, lineWidth: DesignBook.Size.strokeRegular)
                }
        }
        .shadow(.large)
    }

    var trophyIcon: some View {
        ZStack {
            // Ambient halo behind the trophy disc.
            HeroGlow(.trophy, fill: DesignBook.Gradient.celebration, opacity: DesignBook.Opacity.vivid)

            Circle()
                .fill(DesignBook.Gradient.celebration)
                .frame(width: DesignBook.Size.heroDiscSmall, height: DesignBook.Size.heroDiscSmall)
                .shadow(.celebration)

            Image(systemName: "trophy.fill")
                .font(DesignBook.IconFont.extraLarge)
                .fontWeight(.bold)
                .foregroundStyle(DesignBook.Color.onGradient)
                .symbolEffect(.bounce.up.byLayer, options: .nonRepeating, value: hasCelebrated)
        }
        .accessibilityHidden(true)
    }

    func singleWinnerLabel(winner: Team) -> some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            Text(localized("game.results.winner"))
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .eyebrowUppercase()
                .tracking(1.6)

            Text(winner.name)
                .font(DesignBook.Font.displayMedium)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(DesignBook.Color.teamText(for: winner.color))
                .multilineTextAlignment(.center)

            AnimatedScoreText(
                value: scoreboard.totalScore(for: winner),
                font: DesignBook.Font.displayLarge,
                color: DesignBook.Color.teamText(for: winner.color)
            )

            Text(localized("game.results.totalPoints"))
                .font(DesignBook.Font.subheadline)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
                .eyebrowUppercase()
                .tracking(1.2)
        }
    }

    var multipleWinnersLabel: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            Text(localized("game.results.winners"))
                .font(DesignBook.Font.displaySmall)
                .foregroundStyle(DesignBook.Color.Text.primary)

            VStack(spacing: DesignBook.Spacing.sm) {
                ForEach(winners) { winner in
                    VStack(spacing: DesignBook.Spacing.xs) {
                        Text(winner.name)
                            .font(DesignBook.Font.title1)
                            .foregroundStyle(DesignBook.Color.teamText(for: winner.color))

                        AnimatedScoreText(
                            value: scoreboard.totalScore(for: winner),
                            font: DesignBook.Font.displaySmall,
                            color: DesignBook.Color.teamText(for: winner.color)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Round sections
private extension ResultsView {
    var allRoundsSection: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            ForEach(engine.state.startedRounds, id: \.rawValue) { round in
                roundSection(for: round)
            }
        }
    }

    func roundSection(for round: GameRound) -> some View {
        FoldableCard(
            isExpanded: Binding(
                get: { expandedRounds.contains(round) },
                set: { isExpanded in
                    if isExpanded {
                        expandedRounds.insert(round)
                    } else {
                        expandedRounds.remove(round)
                    }
                }
            ),
            title: round.title,
            description: round.description,
            icon: round.symbol
        ) {
            roundScores(for: round)
        }
    }

    func roundScores(for round: GameRound) -> some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            ForEach(Array(scoreboard.ranking(in: round).enumerated()), id: \.element.id) { index, team in
                TeamScoreRowView(
                    team: team,
                    rank: index + 1,
                    score: scoreboard.score(for: team, in: round),
                    isWinner: index == 0
                )
            }
        }
    }

    var totalScoresSection: some View {
        FoldableCard(
            isExpanded: $isTotalScoresExpanded,
            title: localized("game.results.totalScores")
        ) {
            totalScoresContent
        }
    }

    var totalScoresContent: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            ForEach(Array(scoreboard.totalRanking().enumerated()), id: \.element.id) { index, team in
                TeamScoreRowView(
                    team: team,
                    rank: index + 1,
                    score: scoreboard.totalScore(for: team),
                    isWinner: index == 0
                )
            }
        }
    }
}

// MARK: - Actions
private extension ResultsView {
    @ViewBuilder
    var actionSection: some View {
        if isFinal {
            VStack(spacing: DesignBook.Spacing.sm) {
                newWordsButton
                playAgainButton
            }
            .disabled(!areFinalActionsArmed)
        }
    }

    var playAgainButton: some View {
        VStack(spacing: DesignBook.Spacing.xs) {
            PrimaryButton(title: localized("game.results.playAgain"), icon: "arrow.counterclockwise.circle.fill") {
                handlePlayAgain()
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityHint(Text(localized("game.results.playAgain.note")))
            .accessibilityIdentifier("results.playAgain")

            Text(localized("game.results.playAgain.note"))
                .font(DesignBook.Font.footnote)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .accessibilityHidden(true)
        }
    }

    var newWordsButton: some View {
        SecondaryButton(title: localized("game.results.newWords"), icon: "text.bubble.fill") {
            handleNewWords()
        }
    }

    func handleAppear() {
        expandedRounds = isFinal ? Set(GameRound.allCases) : [engine.state.round]
    }

    /// Same teams and words, scores reset; back to choosing who starts.
    func handlePlayAgain() {
        gameManager.rematch()
        navigator.dismissToRoot()
        navigator.push(.randomization)
    }

    /// Same teams, an empty hat; back to Fill the Hat to collect new words.
    func handleNewWords() {
        gameManager.startOverWithNewWords()
        navigator.dismissToRoot()
        navigator.push(.wordSource)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ResultsView()
    }
    .environment(Navigator())
    .environment(GameManager())
    .environment(GameManager().engine)
}
