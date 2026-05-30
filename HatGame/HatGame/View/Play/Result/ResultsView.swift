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
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isTotalScoresExpanded = false
    @State private var expandedRounds: Set<GameRound> = []
    @State private var hasCelebrated = false

    private var round: GameRound? { gameManager.currentRound }
    private var isFinal: Bool { round == nil }

    private var winners: [Team] {
        let sortedTeams = gameManager.getSortedTeamsByTotalScore()
        guard let topScore = sortedTeams.first.map({ gameManager.getTotalScore(for: $0) }) else {
            return []
        }
        return sortedTeams.filter { gameManager.getTotalScore(for: $0) == topScore }
    }

    var body: some View {
        content
            .navigationTitle(
                String(localized: isFinal ? "game.results.gameOverTitle" : "game.results.roundResultsTitle")
            )
            .setDefaultStyle()
            .overlay(alignment: .top) {
                if isFinal {
                    ConfettiView(isActive: hasCelebrated)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .onAppear(perform: handleAppear)
            .task {
                guard isFinal else { return }
                try? await Task.sleep(for: .milliseconds(180))
                hasCelebrated = true
            }
            .sensoryFeedback(.success, trigger: hasCelebrated)
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
        .safeAreaInset(edge: .bottom) {
            actionSection
                .paddingHorizontalDefault()
                .withFooterGradient()
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
                        .fill(DesignBook.Gradient.celebration.opacity(0.32))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.78, blue: 0.27).opacity(0.6),
                                    Color(red: 1.0, green: 0.45, blue: 0.40).opacity(0.2),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
        }
        .shadow(.large)
    }

    var trophyIcon: some View {
        ZStack {
            // Ambient halo behind the trophy disc.
            Circle()
                .fill(DesignBook.Gradient.celebration)
                .frame(width: 140, height: 140)
                .blur(radius: 32)
                .opacity(0.65)

            Circle()
                .fill(DesignBook.Gradient.celebration)
                .frame(width: 96, height: 96)
                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.55), radius: 22, x: 0, y: 10)

            Image(systemName: "trophy.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce.up.byLayer, options: .nonRepeating, value: hasCelebrated)
        }
        .accessibilityHidden(true)
    }

    func singleWinnerLabel(winner: Team) -> some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            Text("game.results.winner")
                .font(DesignBook.Font.headline)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .textCase(.uppercase)
                .tracking(1.6)

            Text(winner.name)
                .font(DesignBook.Font.title)
                .foregroundStyle(winner.color)
                .multilineTextAlignment(.center)

            AnimatedScoreText(
                value: gameManager.getTotalScore(for: winner),
                font: .system(size: 56, weight: .bold, design: .rounded),
                color: winner.color
            )

            Text("game.results.totalPoints")
                .font(DesignBook.Font.caption)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
                .textCase(.uppercase)
                .tracking(1.2)
        }
    }

    var multipleWinnersLabel: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            Text("game.results.winners")
                .font(DesignBook.Font.title2)
                .foregroundStyle(DesignBook.Color.Text.primary)

            VStack(spacing: DesignBook.Spacing.sm) {
                ForEach(winners) { winner in
                    VStack(spacing: DesignBook.Spacing.xs) {
                        Text(winner.name)
                            .font(DesignBook.Font.title3)
                            .foregroundStyle(winner.color)

                        AnimatedScoreText(
                            value: gameManager.getTotalScore(for: winner),
                            font: DesignBook.Font.title2,
                            color: winner.color
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
            ForEach(gameManager.getStartedRounds(), id: \.rawValue) { round in
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
            ForEach(Array(gameManager.getSortedTeamsByRoundScore(for: round).enumerated()), id: \.element.id) { index, team in
                TeamScoreRowView(
                    team: team,
                    rank: index + 1,
                    score: gameManager.getScore(for: team, in: round),
                    isWinner: index == 0
                )
            }
        }
    }

    var totalScoresSection: some View {
        FoldableCard(
            isExpanded: $isTotalScoresExpanded,
            title: String(localized: "game.results.totalScores")
        ) {
            totalScoresContent
        }
    }

    var totalScoresContent: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            ForEach(Array(gameManager.getSortedTeamsByTotalScore().enumerated()), id: \.element.id) { index, team in
                TeamScoreRowView(
                    team: team,
                    rank: index + 1,
                    score: gameManager.getTotalScore(for: team),
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
            VStack(spacing: DesignBook.Spacing.md) {
                playAgainButton
                returnToMainButton
            }
        }
    }

    var playAgainButton: some View {
        VStack(spacing: DesignBook.Spacing.xs) {
            PrimaryButton(title: String(localized: "game.results.playAgain"), icon: "arrow.counterclockwise.circle.fill") {
                handlePlayAgain()
            }

            Text("game.results.playAgain.note")
                .font(DesignBook.Font.caption)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
    }

    var returnToMainButton: some View {
        SecondaryButton(title: String(localized: "game.results.returnToMain"), icon: "house.fill") {
            handleReturnToMain()
        }
    }

    func handleAppear() {
        if !isFinal, let currentRound = round {
            expandedRounds = [currentRound]
        } else if isFinal {
            expandedRounds = Set(GameRound.allCases)
        }
    }

    func handlePlayAgain() {
        DesignBook.Haptics.tap()
        gameManager.resetForNewGame()
        navigator.dismissToRoot()
        navigator.push(.wordSettings)
    }

    func handleReturnToMain() {
        DesignBook.Haptics.tap()
        navigator.dismissToRoot()
        navigator.dismiss()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ResultsView()
    }
    .environment(Navigator())
    .environment(GameManager())
}
