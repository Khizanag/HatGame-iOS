//
//  NextTeamView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct NextTeamView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(GameManager.self) private var gameManager
    @Environment(GameEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let round: GameRound
    let team: Team

    @State private var isStandingsPresented = false
    @State private var selectedExplainerIndex: Int = 0
    @State private var isRandomizingExplainer: Bool = false
    /// Play stays disabled for a moment after the screen appears, so a double
    /// tap on the previous screen's Continue (same spot) can't start the turn.
    @State private var isPlayArmed = false
    /// Changing this starts an explainer shuffle; the task is cancelled on disappear.
    @State private var explainerShuffleId: UUID?
    @ScaledMetric(relativeTo: .body) private var selectionIndicatorSize = DesignBook.Size.selectionIndicatorSize

    private var isFirstPlay: Bool { engine.state.canSelectExplainer(for: team) }
    private var currentExplainer: Player? { engine.state.explainer(for: team) }
    private var currentGuessers: [Player] { engine.state.guessers(for: team) }
    private var hasGameStarted: Bool { engine.scoreboard.hasAnyScore }

    var body: some View {
        content
            .navigationTitle(localized("game.nextTeam.title"))
            .setDefaultStyle()
            .toolbar {
                StandingsToolbarItem { isStandingsPresented = true }
            }
            .sheet(isPresented: $isStandingsPresented) {
                StandingsSheet()
                    .environment(gameManager)
                    .environment(engine)
                    .environment(navigator)
            }
            .onAppear {
                if let explainerIndex = engine.state.explainerIndex(for: team) {
                    selectedExplainerIndex = explainerIndex
                }
            }
            .task(id: explainerShuffleId) {
                await shuffleExplainer()
            }
            .task {
                try? await Task.sleep(for: .milliseconds(400))
                isPlayArmed = true
            }
    }
}

// MARK: - Composition
private extension NextTeamView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                hero
                rolesCard
                roundStatusCard
            }
            .paddingHorizontalDefault()
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .actionBar {
            playButton
                .paddingHorizontalDefault()
        }
    }

    var hero: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            ZStack {
                Circle()
                    .fill(team.color.opacity(0.15))
                    .frame(width: 120, height: 120)

                Circle()
                    .strokeBorder(team.color.opacity(0.4), lineWidth: 2)
                    .frame(width: 120, height: 120)

                Text(verbatim: "🎯")
                    .font(DesignBook.IconFont.emoji)
            }
            .accessibilityHidden(true)
            .decorativeHeroSizing()

            Text(team.name)
                .font(DesignBook.Font.displayLarge)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(DesignBook.Color.teamText(for: team.color))
                .multilineTextAlignment(.center)

            if hasGameStarted {
                HStack(spacing: DesignBook.Spacing.xs) {
                    Image(systemName: "star.fill")
                        .font(DesignBook.Font.subheadlineSemibold)
                    AnimatedScoreText(
                        value: engine.scoreboard.totalScore(for: team),
                        font: DesignBook.Font.title3,
                        color: DesignBook.Color.teamText(for: team.color)
                    )
                    Text(localized("game.currentScoreLabel.suffix"))
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .eyebrowUppercase()
                        .tracking(1.2)
                }
                .foregroundStyle(DesignBook.Color.teamText(for: team.color))
                .padding(.horizontal, DesignBook.Spacing.md)
                .padding(.vertical, DesignBook.Spacing.sm)
                .background {
                    Capsule().fill(team.color.opacity(0.12))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(localized("game.currentScoreLabel \(engine.scoreboard.totalScore(for: team))")))
            }
        }
        .padding(.top, DesignBook.Spacing.md)
    }

    var roundStatusCard: some View {
        GameCard {
            HStack(spacing: DesignBook.Spacing.md) {
                CircularIconContainer(
                    icon: "flag.fill",
                    size: 48,
                    iconSize: 22,
                    color: team.color,
                    backgroundColor: team.color.opacity(0.12)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(round.title)
                        .font(DesignBook.Font.title3)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                        .accessibilityIdentifier("nextTeam.roundTitle")
                    Text(String(format: localized("game.wordsRemainingLabel"), engine.state.remainingWordCount))
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    var rolesCard: some View {
        if isFirstPlay {
            roleSelectionCard
        } else {
            TeamRolesCard(team: team, explainer: currentExplainer, guessers: currentGuessers)
        }
    }

    var roleSelectionCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                        Text(localized("game.nextTeam.selectExplainer"))
                            .font(DesignBook.Font.title3)
                            .foregroundStyle(DesignBook.Color.Text.primary)

                        Text(localized("game.nextTeam.selectExplainer.description"))
                            .font(DesignBook.Font.subheadline)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                    }

                    Spacer()

                    shuffleExplainerButton
                }

                GlassContainer(spacing: DesignBook.Spacing.xs) {
                    VStack(spacing: DesignBook.Spacing.sm) {
                        ForEach(Array(team.players.enumerated()), id: \.element.id) { index, player in
                            Button {
                                guard !isRandomizingExplainer else { return }
                                withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
                                    selectedExplainerIndex = index
                                }
                            } label: {
                                playerSelectionRow(
                                    player: player,
                                    index: index,
                                    isSelected: selectedExplainerIndex == index
                                )
                            }
                            .buttonStyle(.glassCard(selection: selectedExplainerIndex == index ? team.color : nil))
                            .disabled(isRandomizingExplainer)
                            .accessibilityAddTraits(selectedExplainerIndex == index ? .isSelected : [])
                        }
                    }
                }
            }
        }
    }

    var shuffleExplainerButton: some View {
        Button(action: randomizeExplainer) {
            Image(systemName: isRandomizingExplainer ? "sparkles" : "shuffle")
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.accent)
                .symbolEffect(.pulse, options: .repeating, isActive: isRandomizingExplainer && !reduceMotion)
        }
        .glassIconButtonStyle()
        .disabled(isRandomizingExplainer || team.players.count < 2)
        .accessibilityLabel(Text(localized("game.nextTeam.shuffleExplainer")))
        .help(localized("game.nextTeam.shuffleExplainer"))
    }

    func playerSelectionRow(player: Player, index: Int, isSelected: Bool) -> some View {
        HStack(spacing: DesignBook.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(
                        isSelected ? team.color : DesignBook.Color.Text.tertiary.opacity(DesignBook.Opacity.medium),
                        lineWidth: 2
                    )
                    .frame(width: selectionIndicatorSize, height: selectionIndicatorSize)

                if isSelected {
                    Circle()
                        .fill(team.color)
                        .frame(width: selectionIndicatorSize * 2 / 3, height: selectionIndicatorSize * 2 / 3)
                }
            }

            Text(player.name)
                .font(isSelected ? DesignBook.Font.bodySemibold : DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Spacer()

            roleBadge(isSelected: isSelected)
        }
    }

    func roleBadge(isSelected: Bool) -> some View {
        let text = localized(isSelected ? "game.nextTeam.role.explaining" : "game.nextTeam.role.guessing")
        let fg: Color = isSelected ? DesignBook.Color.teamText(for: team.color) : DesignBook.Color.Text.secondary
        let bg: Color = isSelected ? team.color.opacity(0.15) : DesignBook.Color.Background.card

        return Text(text)
            .font(DesignBook.Font.subheadlineSemibold)
            .eyebrowUppercase()
            .tracking(1.1)
            .foregroundStyle(fg)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.vertical, 6)
            .background(Capsule().fill(bg))
    }

    var playButton: some View {
        PrimaryButton(title: localized("common.buttons.play"), icon: "play.fill") {
            DesignBook.Haptics.confirm()
            engine.beginTurn(explainerIndex: isFirstPlay ? selectedExplainerIndex : nil)
        }
        .keyboardShortcut(.defaultAction)
        .disabled(isRandomizingExplainer || !isPlayArmed)
        .accessibilityIdentifier("nextTeam.play")
    }
}

// MARK: - Actions
private extension NextTeamView {
    /// Starts the "who explains" shuffle: the highlight cycles through the
    /// players with haptics, then settles on a random pick — mirroring the
    /// starting-team randomizer. Reduce Motion skips straight to the pick.
    func randomizeExplainer() {
        guard !isRandomizingExplainer, team.players.count > 1 else { return }
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            isRandomizingExplainer = true
        }
        explainerShuffleId = UUID()
    }

    func shuffleExplainer() async {
        guard explainerShuffleId != nil, team.players.count > 1 else { return }
        let playerCount = team.players.count
        if !reduceMotion {
            for _ in 1...20 {
                guard (try? await Task.sleep(for: .milliseconds(100))) != nil else { return }
                withAnimation(.easeInOut(duration: 0.1)) {
                    selectedExplainerIndex = Int.random(in: 0..<playerCount)
                }
            }
            guard (try? await Task.sleep(for: .milliseconds(300))) != nil else { return }
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6)) {
            selectedExplainerIndex = Int.random(in: 0..<playerCount)
            isRandomizingExplainer = false
        }
        DesignBook.Haptics.success()
    }
}
