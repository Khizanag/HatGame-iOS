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
    /// Changing this starts an explainer shuffle; the task is cancelled on disappear.
    @State private var explainerShuffleId: UUID?
    @ScaledMetric(relativeTo: .body) private var selectionIndicatorSize = DesignBook.Size.selectionIndicatorSize

    private var isFirstPlay: Bool { engine.state.canSelectExplainer(for: team) }
    private var currentExplainer: Player? { engine.state.explainer(for: team) }
    private var currentGuessers: [Player] { engine.state.guessers(for: team) }
    private var hasGameStarted: Bool { engine.scoreboard.hasAnyScore }

    var body: some View {
        content
            .setDefaultStyle()
            .sheet(isPresented: $isStandingsPresented) {
                NavigationStack {
                    ResultsView()
                }
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
        .safeAreaInset(edge: .bottom) {
            buttonsSection
                .paddingHorizontalDefault()
                .withFooterGradient()
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

            Text(localized("game.nextTeam.title"))
                .font(DesignBook.Font.smallCaption)
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(DesignBook.Color.Text.tertiary)

            Text(team.name)
                .font(DesignBook.Font.largeTitle)
                .foregroundStyle(team.color)
                .multilineTextAlignment(.center)

            if hasGameStarted {
                HStack(spacing: DesignBook.Spacing.xs) {
                    Image(systemName: "star.fill")
                        .font(DesignBook.Font.captionBold)
                    AnimatedScoreText(
                        value: engine.scoreboard.totalScore(for: team),
                        font: DesignBook.Font.headline,
                        color: team.color
                    )
                    Text(localized("game.currentScoreLabel.suffix"))
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .foregroundStyle(team.color)
                .padding(.horizontal, DesignBook.Spacing.md)
                .padding(.vertical, DesignBook.Spacing.sm)
                .background {
                    Capsule().fill(team.color.opacity(0.12))
                }
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
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                        .accessibilityIdentifier("nextTeam.roundTitle")
                    Text(String(format: localized("game.wordsRemainingLabel"), engine.state.remainingWordCount))
                        .font(DesignBook.Font.caption)
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
            currentRolesCard
        }
    }

    var roleSelectionCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                        Text(localized("game.nextTeam.selectExplainer"))
                            .font(DesignBook.Font.headline)
                            .foregroundStyle(DesignBook.Color.Text.primary)

                        Text(localized("game.nextTeam.selectExplainer.description"))
                            .font(DesignBook.Font.caption)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                    }

                    Spacer()

                    Button(action: randomizeExplainer) {
                        Image(systemName: isRandomizingExplainer ? "sparkles" : "shuffle")
                            .font(DesignBook.Font.body)
                            .foregroundStyle(DesignBook.Color.Text.accent)
                            .symbolEffect(.pulse, options: .repeating, isActive: isRandomizingExplainer)
                            .padding(DesignBook.Spacing.sm)
                            .background(DesignBook.Color.Background.secondary)
                            .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                    }
                    .disabled(isRandomizingExplainer || team.players.count < 2)
                    .accessibilityLabel(Text(localized("game.nextTeam.shuffleExplainer")))
                }

                VStack(spacing: DesignBook.Spacing.sm) {
                    ForEach(Array(team.players.enumerated()), id: \.element.id) { index, player in
                        Button {
                            guard !isRandomizingExplainer else { return }
                            DesignBook.Haptics.selection()
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
                        .buttonStyle(.plain)
                        .disabled(isRandomizingExplainer)
                    }
                }
            }
        }
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
                .font(isSelected ? DesignBook.Font.bodyBold : DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Spacer()

            roleBadge(isSelected: isSelected)
        }
        .padding(DesignBook.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                .fill(isSelected ? team.color.opacity(0.08) : DesignBook.Color.Background.secondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
                .strokeBorder(isSelected ? team.color.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }

    func roleBadge(isSelected: Bool) -> some View {
        let text: LocalizedStringKey = isSelected ? "game.nextTeam.role.explaining" : "game.nextTeam.role.guessing"
        let fg: Color = isSelected ? team.color : DesignBook.Color.Text.secondary
        let bg: Color = isSelected ? team.color.opacity(0.15) : DesignBook.Color.Background.card

        return Text(text)
            .font(DesignBook.Font.captionBold)
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(fg)
            .padding(.horizontal, DesignBook.Spacing.sm)
            .padding(.vertical, 6)
            .background(Capsule().fill(bg))
    }

    var currentRolesCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack {
                    Text(localized("game.nextTeam.teamRoles"))
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Spacer()

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                }

                VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                    if let explainer = currentExplainer {
                        roleSection(
                            icon: "person.wave.2.fill",
                            iconColor: team.color,
                            label: "game.nextTeam.role.explaining",
                            content: { explainerRow(explainer) }
                        )
                    }

                    if !currentGuessers.isEmpty {
                        roleSection(
                            icon: "lightbulb.fill",
                            iconColor: DesignBook.Color.Text.accent,
                            label: "game.nextTeam.role.guessing",
                            content: { guessersList }
                        )
                    }
                }
            }
        }
    }

    func roleSection<Content: View>(
        icon: String,
        iconColor: Color,
        label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            HStack(spacing: DesignBook.Spacing.xs) {
                Image(systemName: icon)
                    .font(DesignBook.Font.caption)
                    .foregroundStyle(iconColor)

                Text(label)
                    .font(DesignBook.Font.smallCaption)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
            }
            content()
        }
    }

    func explainerRow(_ explainer: Player) -> some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Circle()
                .fill(team.color.opacity(DesignBook.Opacity.semiTransparent))
                .frame(width: DesignBook.Size.dotSmall, height: DesignBook.Size.dotSmall)

            Text(explainer.name)
                .font(DesignBook.Font.bodyBold)
                .foregroundStyle(team.color)
        }
        .padding(DesignBook.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(team.color.opacity(DesignBook.Opacity.light))
        .cornerRadius(DesignBook.Size.smallCardCornerRadius)
    }

    var guessersList: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
            ForEach(currentGuessers) { guesser in
                HStack(spacing: DesignBook.Spacing.sm) {
                    Circle()
                        .fill(DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.medium))
                        .frame(width: DesignBook.Size.dotSmall, height: DesignBook.Size.dotSmall)

                    Text(guesser.name)
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                }
                .padding(.horizontal, DesignBook.Spacing.sm)
                .padding(.vertical, DesignBook.Spacing.xs)
            }
        }
        .padding(DesignBook.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignBook.Color.Background.secondary)
        .cornerRadius(DesignBook.Size.smallCardCornerRadius)
    }

    var buttonsSection: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            SecondaryButton(title: localized("game.turnResults.checkStandings"), icon: "list.bullet.rectangle") {
                DesignBook.Haptics.tap()
                isStandingsPresented = true
            }

            PrimaryButton(title: localized("common.buttons.play"), icon: "play.fill") {
                DesignBook.Haptics.confirm()
                engine.beginTurn(explainerIndex: isFirstPlay ? selectedExplainerIndex : nil)
            }
            .disabled(isRandomizingExplainer)
            .accessibilityIdentifier("nextTeam.play")
        }
    }
}

// MARK: - Actions
private extension NextTeamView {
    /// Starts the "who explains" shuffle: the highlight cycles through the
    /// players with haptics, then settles on a random pick — mirroring the
    /// starting-team randomizer. Reduce Motion skips straight to the pick.
    func randomizeExplainer() {
        guard !isRandomizingExplainer, team.players.count > 1 else { return }
        DesignBook.Haptics.tap()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            isRandomizingExplainer = true
        }
        explainerShuffleId = UUID()
    }

    func shuffleExplainer() async {
        guard explainerShuffleId != nil, team.players.count > 1 else { return }
        let playerCount = team.players.count
        if !reduceMotion {
            for cycle in 1...20 {
                guard (try? await Task.sleep(for: .milliseconds(100))) != nil else { return }
                withAnimation(.easeInOut(duration: 0.1)) {
                    selectedExplainerIndex = Int.random(in: 0..<playerCount)
                }
                if cycle.isMultiple(of: 3) {
                    DesignBook.Haptics.selection()
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
