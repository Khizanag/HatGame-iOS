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

    private var selectedTeam: Team {
        gameManager.configuration.teams[selectedStartingTeamIndex]
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
        .toolbar(isShuffling ? .hidden : .automatic, for: .navigationBar)
        .interactiveDismissDisabled(isShuffling)
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

            if showTeamReveal {
                RevealedTeamCard(team: selectedTeam, isRevealed: showTeamReveal)
                    .transition(.scale.combined(with: .opacity))
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
                            .symbolEffect(.pulse, options: .repeating, isActive: isRandomizingTeam)

                        Text(localized("randomization.startingTeam.randomize"))
                            .font(DesignBook.Font.caption)
                    }
                    .foregroundStyle(DesignBook.Color.Text.accent)
                    .padding(.horizontal, DesignBook.Spacing.md)
                    .padding(.vertical, DesignBook.Spacing.sm)
                    .background(DesignBook.Color.Text.accent.opacity(0.1))
                    .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                }
                .buttonStyle(.plain)
                .disabled(isRandomizingTeam)
            }
        }
    }

    var teamsList: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            ForEach(Array(gameManager.configuration.teams.enumerated()), id: \.offset) { index, team in
                TeamSelectionRow(
                    team: team,
                    isSelected: selectedStartingTeamIndex == index
                )
                .onTapGesture {
                    selectTeam(at: index)
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
        .disabled(isShuffling || isRandomizingTeam)
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
        guard !isRandomizingTeam else { return }
        DesignBook.Haptics.tap()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            isRandomizingTeam = true
            showTeamReveal = false
        }

        var cycleCount = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            cycleCount += 1
            let teamCount = gameManager.configuration.teams.count
            withAnimation(.easeInOut(duration: 0.1)) {
                selectedStartingTeamIndex = Int.random(in: 0..<teamCount)
            }
            if cycleCount % 3 == 0 {
                Task { @MainActor in DesignBook.Haptics.selection() }
            }
            guard cycleCount >= 20 else { return }
            timer.invalidate()
            finalizeRandomTeamSelection(teamCount: teamCount)
        }
    }

    func finalizeRandomTeamSelection(teamCount: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                selectedStartingTeamIndex = Int.random(in: 0..<teamCount)
                isRandomizingTeam = false
                showTeamReveal = true
            }
            DesignBook.Haptics.success()
        }
    }

    func shuffleAndStart() {
        DesignBook.Haptics.confirm()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            isShuffling = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            gameManager.start(startingTeamIndex: selectedStartingTeamIndex)
            navigator.push(.nextTeam(round: .first, team: gameManager.currentTeam))
        }
    }
}

// MARK: - Subview types
private struct RandomizationHeaderCard: View {
    var body: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                CircularIconContainer(
                    icon: "sparkles",
                    size: DesignBook.Size.cardLarge,
                    iconSize: 35,
                    color: DesignBook.Color.Text.accent,
                    gradientColors: [
                        DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.highlight),
                        DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.veryLight),
                    ]
                )
                .symbolEffect(.pulse, options: .repeating)

                VStack(spacing: DesignBook.Spacing.xs) {
                    Text(localized("randomization.header.title"))
                        .font(DesignBook.Font.title2)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Text(localized("randomization.header.subtitle"))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DesignBook.Spacing.md)
        }
    }
}

private struct WordsReadyCard: View {
    let wordCount: Int

    var body: some View {
        GameCard {
            HStack(spacing: DesignBook.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignBook.Size.smallCardCornerRadius)
                        .fill(DesignBook.Color.Status.success.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(DesignBook.Color.Status.success)
                }

                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    Text(localized("randomization.wordsReady.title"))
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Text(String(format: localized("randomization.wordsReady.count"), wordCount))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                Spacer()
            }
            .padding(DesignBook.Spacing.md)
        }
    }
}

private struct TeamSelectionRow: View {
    let team: Team
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            RoundedRectangle(cornerRadius: DesignBook.Size.smallCardCornerRadius)
                .fill(team.color)
                .frame(width: 8)

            VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                Text(team.name)
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                Text(String(format: localized("randomization.team.players"), team.players.count))
                    .font(DesignBook.Font.caption)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(DesignBook.IconFont.medium)
                .foregroundStyle(isSelected ? DesignBook.Color.Text.accent : DesignBook.Color.Text.tertiary)
        }
        .padding(DesignBook.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                .fill(DesignBook.Color.Background.card)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                        .stroke(isSelected ? team.color : Color.clear, lineWidth: 2)
                }
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RevealedTeamCard: View {
    let team: Team
    let isRevealed: Bool

    var body: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.lg) {
                trophyIcon

                VStack(spacing: DesignBook.Spacing.sm) {
                    Text(localized("randomization.startingTeam.selected"))
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.secondary)

                    Text(team.name)
                        .font(DesignBook.Font.title)
                        .fontWeight(.bold)
                        .foregroundStyle(team.color)

                    Text(localized("randomization.startingTeam.goesFirst"))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                playersList
            }
            .padding(DesignBook.Spacing.lg)
        }
    }

    private var trophyIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [team.color.opacity(0.3), team.color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)

            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundStyle(team.color)
                .symbolEffect(.bounce, value: isRevealed)
        }
    }

    private var playersList: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
            ForEach(team.players) { player in
                HStack(spacing: DesignBook.Spacing.sm) {
                    Circle()
                        .fill(team.color.opacity(0.3))
                        .frame(width: 8, height: 8)

                    Text(player.name)
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.primary)
                }
            }
        }
        .padding(DesignBook.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignBook.Color.Background.secondary)
        .cornerRadius(DesignBook.Size.smallCardCornerRadius)
    }
}

private struct ShufflingOverlay: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let reduceMotion: Bool

    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: DesignBook.Spacing.xl) {
                hatBadge

                VStack(spacing: DesignBook.Spacing.sm) {
                    Text(localized("randomization.shuffling.message"))
                        .font(DesignBook.Font.title2)
                        .foregroundStyle(.white)

                    ProgressDotIndicator(
                        count: 3,
                        currentIndex: 1,
                        dotSize: DesignBook.Size.dotMedium,
                        spacing: 4,
                        completedColor: .white.opacity(DesignBook.Opacity.mostlyOpaque),
                        currentColor: .white.opacity(DesignBook.Opacity.mostlyOpaque),
                        pendingColor: .white.opacity(DesignBook.Opacity.mostlyOpaque)
                    )
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }

    private var hatBadge: some View {
        ZStack {
            Circle()
                .fill(DesignBook.Gradient.primary)
                .frame(width: 144, height: 144)
                .blur(radius: 24)
                .opacity(0.7)

            disc

            Text("🎩")
                .font(.system(size: 72))
                .rotation3DEffect(.degrees(rotationAngle), axis: (x: 0.2, y: 1.0, z: 0.0))
        }
    }

    private var disc: some View {
        ZStack {
            if reduceTransparency {
                Circle().fill(DesignBook.Color.Background.card)
            } else {
                Circle().fill(.thinMaterial)
            }
        }
        .frame(width: 128, height: 128)
        .overlay {
            Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 12)
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
