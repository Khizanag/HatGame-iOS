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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isShuffling: Bool = false
    @State private var isRandomizingTeam: Bool = false
    @State private var selectedStartingTeamIndex: Int = 0
    @State private var showTeamReveal: Bool = false
    /// Changing this starts a starting-team shuffle; the task is cancelled on disappear.
    @State private var teamShuffleId: UUID?
    /// Set once the game starts, so a skip tap and the timer can't both start it.
    @State private var hasStartedGame = false
    /// Seconds the shuffle overlay runs: in full the first time this session.
    @State private var shuffleDuration = RandomizationView.fullShuffleSeconds
    /// Bumped on each reveal to fire the confetti.
    @State private var revealBurst = 0
    @State private var teamPicks = 0

    private static let fullShuffleSeconds = 2.6
    private static let shortShuffleSeconds = 0.8

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
                .accessibilityHidden(isShuffling)

            if isShuffling {
                ShufflingOverlay(reduceMotion: reduceMotion, duration: shuffleDuration, onSkip: startGame)
                    .transition(.opacity)
            }
        }
        .navigationTitle(localized("randomization.title"))
        .setDefaultStyle()
        .navigationBarBackButtonHidden(isShuffling)
        .haptic(.selection, trigger: teamPicks)
        .haptic(.selection, trigger: revealBurst)
        .hidesNavigationBar(isShuffling)
        .interactiveDismissDisabled(isShuffling)
        .onAppear(perform: resetForNewGame)
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
            VStack(spacing: DesignBook.Spacing.lg) {
                hero
                startingTeamSection
                Spacer()
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        // Inside the action bar's content, so the confetti falls behind the button.
        .overlay {
            ConfettiView(isActive: showTeamReveal, palette: confettiPalette, retriggerId: revealBurst)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .actionBar {
            shuffleButton
                .paddingHorizontalDefault()
                .padding(.bottom, DesignBook.Spacing.sm)
        }
    }

    var startingTeamSection: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            startingTeamHeader

            if showTeamReveal, let selectedTeam {
                RevealedTeamCard(team: selectedTeam, isRevealed: showTeamReveal)
                    .transition(reduceMotion ? .opacity : .cardFlip)
                    .accessibilityIdentifier("randomization.revealedTeam")
            } else {
                teamsList
            }
        }
    }

    /// The filled hat, and how many words are in it.
    var hero: some View {
        VStack(spacing: DesignBook.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(DesignBook.Gradient.primary)
                    .frame(width: 150, height: 150)
                    .blur(radius: 34)
                    .opacity(DesignBook.Opacity.semiTransparent)
                Circle()
                    .fill(DesignBook.Color.Background.card)
                    .frame(width: 116, height: 116)
                    .shadow(.large)
                UpturnedHat()
            }
            .frame(height: 150)
            .decorativeHeroSizing()
            .accessibilityHidden(true)

            Text(localized("randomization.header.title"))
                .font(DesignBook.Font.displaySmall)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .accessibilityAddTraits(.isHeader)

            Label(
                localized("randomization.wordsReady.count \(gameManager.configuration.words.count)"),
                systemImage: "checkmark.circle.fill"
            )
            .font(DesignBook.Font.body)
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .symbolRenderingMode(.multicolor)
        }
    }

    /// The starting team's color leads the burst.
    var confettiPalette: [Color] {
        guard let selectedTeam else { return ConfettiView.defaultPalette }
        return [selectedTeam.color, selectedTeam.color] + ConfettiView.defaultPalette
    }

    /// Side by side; stacked at accessibility sizes, where the button would
    /// squeeze to a column of letters (constitution article 15).
    var startingTeamHeader: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignBook.Spacing.sm))
            : AnyLayout(HStackLayout())
        return layout {
            Text(localized("randomization.startingTeam.title"))
                .font(DesignBook.Font.title1)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .accessibilityAddTraits(.isHeader)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            if !showTeamReveal {
                Button(action: randomizeStartingTeam) {
                    HStack(spacing: DesignBook.Spacing.xs) {
                        Image(systemName: isRandomizingTeam ? "sparkles" : "shuffle")
                            .font(DesignBook.Font.subheadline)
                            .symbolEffect(.pulse, options: .repeating, isActive: isRandomizingTeam && !reduceMotion)

                        Text(localized("randomization.startingTeam.randomize"))
                            .font(DesignBook.Font.subheadline)
                    }
                }
                .glassButtonStyle()
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(isRandomizingTeam)
                .accessibilityIdentifier("randomization.randomize")
            }
        }
    }

    var teamsList: some View {
        GlassContainer(spacing: DesignBook.Spacing.xs) {
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
                    .buttonStyle(.glassCard(selection: selectedStartingTeamIndex == index ? team.color : nil))
                    .shadow(color: team.color.opacity(selectedStartingTeamIndex == index ? 0.45 : 0), radius: 14)
                    }
            }
        }
    }

    var shuffleButton: some View {
        PrimaryButton(
            title: localized("randomization.shuffleAndStart"),
            icon: "play.fill",
            action: shuffleAndStart
        )
        .keyboardShortcut(.defaultAction)
        .disabled(isShuffling || isRandomizingTeam || !canStart)
        .accessibilityIdentifier("randomization.start")
    }
}

// MARK: - Actions
private extension RandomizationView {
    func selectTeam(at index: Int) {
        withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
            selectedStartingTeamIndex = index
            showTeamReveal = false
        }
        teamPicks += 1
    }

    func randomizeStartingTeam() {
        guard !isRandomizingTeam, !gameManager.configuration.teams.isEmpty else { return }
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            isRandomizingTeam = true
            showTeamReveal = false
        }
        teamShuffleId = UUID()
    }

    /// Spins the highlight round the teams like a roulette wheel: quick at
    /// first, slowing step by step with a tick each, until it stops on a
    /// team picked up front. Reduce Motion skips straight to the reveal.
    func shuffleStartingTeam() async {
        let teamCount = gameManager.configuration.teams.count
        guard teamShuffleId != nil, teamCount > 0 else { return }
        let winner = Int.random(in: 0..<teamCount)
        if !reduceMotion, teamCount > 1 {
            guard await spinRoulette(to: winner, teamCount: teamCount) else { return }
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.72)) {
            selectedStartingTeamIndex = winner
            isRandomizingTeam = false
            showTeamReveal = true
        }
        revealBurst += 1
    }

    /// Steps the highlight forward, at least a dozen times and whole laps
    /// before landing on `winner`. Returns false if cancelled midway.
    func spinRoulette(to winner: Int, teamCount: Int) async -> Bool {
        let start = selectedStartingTeamIndex
        let laps = max(2, Int((12.0 / Double(teamCount)).rounded(.up)))
        let steps = laps * teamCount + (winner - start + teamCount) % teamCount
        for step in 1...steps {
            let fraction = Double(step) / Double(steps)
            let delay = 0.05 + 0.34 * pow(fraction, 3)
            guard (try? await Task.sleep(for: .seconds(delay))) != nil else { return false }
            withAnimation(.snappy(duration: 0.14)) {
                selectedStartingTeamIndex = (start + step) % teamCount
            }
        }
        return (try? await Task.sleep(for: .milliseconds(380))) != nil
    }

    /// A second Play Again in a row pops back to this same screen, still
    /// holding the last game's shuffle; without a reset the overlay would
    /// stay up with navigation hidden and the start guard shut.
    func resetForNewGame() {
        guard gameManager.engine.phase == .setup else { return }
        isShuffling = false
        hasStartedGame = false
        showTeamReveal = false
    }

    func shuffleAndStart() {
        guard !isShuffling, canStart else { return }
        let isShort = reduceMotion || SessionAnimations.hasPlayedShuffle
        SessionAnimations.hasPlayedShuffle = true
        shuffleDuration = isShort ? Self.shortShuffleSeconds : Self.fullShuffleSeconds
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            isShuffling = true
        }
    }

    /// Lets the shuffle play out — in full only the first time this session
    /// — and the last slip go in, then starts the game. A tap on the overlay
    /// starts it sooner.
    func startGameAfterShuffle() async {
        guard isShuffling else { return }
        guard (try? await Task.sleep(for: .seconds(shuffleDuration + 0.2))) != nil else { return }
        startGame()
    }

    func startGame() {
        guard isShuffling, !hasStartedGame else { return }
        hasStartedGame = true
        gameManager.startGame(startingTeamIndex: selectedStartingTeamIndex)
        guard gameManager.engine.phase == .nextTeam else {
            // Never leave the dimmed overlay up with navigation hidden.
            isShuffling = false
            hasStartedGame = false
            return
        }
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
