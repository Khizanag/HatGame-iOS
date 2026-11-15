//
//  RandomizationView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct RandomizationView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isShuffling: Bool = false
    @State private var isRandomizingTeam: Bool = false
    @State private var selectedStartingTeamIndex: Int = 0
    @State private var showTeamReveal: Bool = false
    /// Changing this starts a starting-team shuffle; the task is cancelled on disappear.
    @State private var teamShuffleId: UUID?

    private var selectedTeam: Team? {
        gameManager.configuration.teams[safe: selectedStartingTeamIndex]
    }

    private var canStart: Bool {
        !gameManager.configuration.words.isEmpty && selectedTeam != nil
    }

    var body: some View {
        ZStack {
            readyContent
                .blur(radius: isShuffling ? 10 : 0)
                .opacity(isShuffling ? 0.3 : 1)
                .allowsHitTesting(!isShuffling)

            if isShuffling {
                ShufflingOverlay(reduceMotion: reduceMotion)
                    .transition(.opacity)
            }
        }
        .navigationTitle(localized("randomization.title"))
        .setDefaultStyle()
        .navigationBarBackButtonHidden(isShuffling)
        .hidesNavigationBar(isShuffling)
        .interactiveDismissDisabled(isShuffling)
        .task(id: teamShuffleId) {
            await shuffleStartingTeam()
        }
        .task(id: isShuffling) {
            await startGameAfterShuffle()
        }
    }
}

// MARK: - Subviews
private extension RandomizationView {
    var readyContent: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.xl) {
                RandomizationHeaderCard()
                WordsReadyCard(wordCount: gameManager.configuration.words.count)
                startingTeamSection
                Spacer()
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            shuffleButton
                .paddingHorizontalDefault()
                .padding(.bottom, DesignBook.Spacing.sm)
                .withFooterGradient()
        }
    }

    var startingTeamSection: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            startingTeamHeader

            if showTeamReveal, let selectedTeam {
                RevealedTeamCard(team: selectedTeam, isRevealed: showTeamReveal)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            } else {
                teamsList
            }
        }
    }

    var startingTeamHeader: some View {
        HStack {
            Text(localized("randomization.startingTeam.title"))
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Spacer()

            if !showTeamReveal {
                Button(action: randomizeStartingTeam) {
                    HStack(spacing: DesignBook.Spacing.xs) {
                        Image(systemName: isRandomizingTeam ? "sparkles" : "shuffle")
                            .font(DesignBook.Font.caption)
                            .symbolEffect(.pulse, options: .repeating, isActive: isRandomizingTeam && !reduceMotion)

                        Text(localized("randomization.startingTeam.randomize"))
                            .font(DesignBook.Font.caption)
                    }
                    .foregroundStyle(DesignBook.Color.Text.accent)
                    .padding(.horizontal, DesignBook.Spacing.md)
                    .padding(.vertical, DesignBook.Spacing.sm)
                    .background(DesignBook.Color.Text.accent.opacity(0.1))
                    .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRandomizingTeam)
            }
        }
    }

    var teamsList: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            ForEach(Array(gameManager.configuration.teams.enumerated()), id: \.offset) { index, team in
                Button {
                    selectTeam(at: index)
                } label: {
                    TeamSelectionRow(
                        team: team,
                        isSelected: selectedStartingTeamIndex == index
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var shuffleButton: some View {
        PrimaryButton(
            title: localized("randomization.shuffleAndStart"),
            icon: "play.fill",
            action: shuffleAndStart
        )
        .disabled(isShuffling || isRandomizingTeam || !canStart)
        .accessibilityIdentifier("randomization.start")
    }
}

// MARK: - Actions
private extension RandomizationView {
    func selectTeam(at index: Int) {
        DesignBook.Haptics.selection()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
            selectedStartingTeamIndex = index
            showTeamReveal = false
        }
    }

    func randomizeStartingTeam() {
        guard !isRandomizingTeam, !gameManager.configuration.teams.isEmpty else { return }
        DesignBook.Haptics.tap()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            isRandomizingTeam = true
            showTeamReveal = false
        }
        teamShuffleId = UUID()
    }

    /// Cycles the highlight through the teams with haptics, then reveals a
    /// random pick. Reduce Motion skips straight to the reveal.
    func shuffleStartingTeam() async {
        let teamCount = gameManager.configuration.teams.count
        guard teamShuffleId != nil, teamCount > 0 else { return }
        if !reduceMotion {
            for cycle in 1...20 {
                guard (try? await Task.sleep(for: .milliseconds(100))) != nil else { return }
                withAnimation(.easeInOut(duration: 0.1)) {
                    selectedStartingTeamIndex = Int.random(in: 0..<teamCount)
                }
                if cycle.isMultiple(of: 3) {
                    DesignBook.Haptics.selection()
                }
            }
            guard (try? await Task.sleep(for: .milliseconds(300))) != nil else { return }
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6)) {
            selectedStartingTeamIndex = Int.random(in: 0..<teamCount)
            isRandomizingTeam = false
            showTeamReveal = true
        }
        DesignBook.Haptics.success()
    }

    func shuffleAndStart() {
        guard !isShuffling, canStart else { return }
        DesignBook.Haptics.confirm()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            isShuffling = true
        }
    }

    /// Lets the shuffle animation play, then starts the game and enters the loop.
    func startGameAfterShuffle() async {
        guard isShuffling else { return }
        guard (try? await Task.sleep(for: reduceMotion ? .milliseconds(600) : .milliseconds(2500))) != nil else {
            return
        }
        gameManager.startGame(startingTeamIndex: selectedStartingTeamIndex)
        guard gameManager.engine.phase == .nextTeam else { return }
        navigator.push(.gameLoop)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        RandomizationView()
    }
    .environment(Navigator())
    .environment(GameManager())
}
