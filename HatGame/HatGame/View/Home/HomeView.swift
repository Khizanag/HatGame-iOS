//
//  HomeView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct HomeView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SceneStorage("HomeView.howToPlay.expanded.v2") private var isHowToPlayExpanded: Bool = false
    @AppStorage("HomeView.hasSeenHowToPlay") private var hasSeenHowToPlay: Bool = false
    @State private var isHeroFloating: Bool = false
    /// The single-device game saved mid-play, offered for resuming.
    @State private var savedGame: GameState?
    @State private var isDiscardConfirmationPresented = false
    @State private var isOverwriteConfirmationPresented = false
    @State private var discardedGames = 0

    private let gameStore = FileGameStore.shared

    var body: some View {
        content
            .background {
                heroBackdrop.ignoresSafeArea()
            }
            .toolbar { settingsToolbar }
            .haptic(.warning, trigger: discardedGames)
            .uiTestDeepLink(navigator)
            // Re-check whenever a flow closes: it may have saved, finished, or replaced a game.
            .task(id: navigator.presentedPage?.id) {
                await loadSavedGame()
            }
            .confirmationDialog(
                localized("home.resume.discard.title"),
                isPresented: $isDiscardConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(localized("home.resume.discard"), role: .destructive, action: discardSavedGame)
                Button(localized("common.buttons.cancel"), role: .cancel) {}
            } message: {
                Text(localized("home.resume.discard.message"))
            }
            .confirmationDialog(
                localized("home.newGame.overwrite.title"),
                isPresented: $isOverwriteConfirmationPresented,
                titleVisibility: .visible
            ) {
                overwriteDialogActions
            } message: {
                Text(localized("home.newGame.overwrite.message"))
            }
    }
}

// MARK: - Composition
private extension HomeView {
    var heroBackdrop: some View {
        ZStack {
            DesignBook.Color.Background.primary
            DesignBook.Gradient.brandBackdrop
                .opacity(0.9)
        }
    }

    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.xl) {
                hero
                if let savedGame {
                    resumeCard(for: savedGame)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                multiDeviceModes
                howToPlayCard
                Spacer().frame(height: DesignBook.Spacing.xl)
            }
        }
        .actionBar {
            actionButtons
        }
        .onAppear {
            #if DEBUG
            // Snapshots need the same Home every launch: no first-run expansion.
            if UITestConfiguration.screen != nil {
                isHowToPlayExpanded = false
                hasSeenHowToPlay = true
            }
            #endif
            if !hasSeenHowToPlay {
                hasSeenHowToPlay = true
                isHowToPlayExpanded = true
            }
            guard !reduceMotion else { return }
            #if DEBUG
            if UITestConfiguration.disablesAnimations { return }
            #endif
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isHeroFloating = true
            }
        }
    }

    var hero: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            heroIcon
                .decorativeHeroSizing()
                .padding(.top, DesignBook.Spacing.lg)

            VStack(spacing: DesignBook.Spacing.xs) {
                Text(localized("home.title"))
                    .font(DesignBook.Font.displayLarge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignBook.Spacing.lg)

                Text(localized("home.subtitle"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignBook.Spacing.lg)
            }
        }
    }

    var heroIcon: some View {
        ZStack {
            // Soft glow halo behind the hat.
            Circle()
                .fill(DesignBook.Gradient.primary)
                .frame(width: 156, height: 156)
                .blur(radius: 36)
                .opacity(0.55)

            // Inner glass disc.
            Circle()
                .fill(DesignBook.Color.Background.card)
                .frame(width: 136, height: 136)
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignBook.Color.Text.accent.opacity(0.4),
                                    DesignBook.Color.Text.accent.opacity(0.0),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(.large)

            Text(verbatim: "🎩")
                .font(DesignBook.IconFont.emojiLarge)
                .offset(y: reduceMotion ? 0 : (isHeroFloating ? -6 : 6))
                .accessibilityHidden(true)
        }
    }

    func resumeCard(for state: GameState) -> some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.md) {
                    CircularIconContainer(
                        icon: "hourglass",
                        size: 48,
                        iconSize: 22,
                        color: DesignBook.Color.Text.accent,
                        backgroundColor: DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.highlight)
                    )
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                        Text(localized("home.resume.title"))
                            .font(DesignBook.Font.title3)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                        Text(resumeSubtitle(for: state))
                            .font(DesignBook.Font.subheadline)
                            .foregroundStyle(DesignBook.Color.Text.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    Spacer(minLength: 0)
                }

                HStack(spacing: DesignBook.Spacing.md) {
                    SecondaryButton(title: localized("home.resume.discard"), icon: "trash", role: .destructive) {
                        isDiscardConfirmationPresented = true
                    }
                    .accessibilityIdentifier("home.discardButton")

                    PrimaryButton(title: localized("home.resume.button"), icon: "play.fill") {
                        navigator.present(.resumeGame(state))
                    }
                    .accessibilityIdentifier("home.resumeButton")
                }
            }
        }
        .paddingHorizontalDefault()
    }

    func resumeSubtitle(for state: GameState) -> String {
        String(
            format: localized("home.resume.subtitle"),
            state.round.rawValue,
            state.currentTeam?.name ?? ""
        )
    }

    var howToPlayCard: some View {
        FoldableCard(
            isExpanded: $isHowToPlayExpanded,
            title: localized("home.howToPlay.title"),
            icon: "sparkles"
        ) {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    InstructionRow(
                        index: index + 1,
                        icon: instruction.icon,
                        text: instruction.text
                    )
                }
            }
        }
        .paddingHorizontalDefault()
    }

    /// The one primary action — Pass and Play — rides in the action bar,
    /// prominent unless a saved game's Resume already is.
    @ViewBuilder
    var actionButtons: some View {
        Group {
            if savedGame == nil {
                PrimaryButton(title: localized("home.localGame"), icon: "person.2.fill", action: startPassAndPlay)
            } else {
                SecondaryButton(title: localized("home.localGame"), icon: "person.2.fill", action: startPassAndPlay)
            }
        }
        .accessibilityIdentifier("home.passAndPlay")
        .paddingHorizontalDefault()
        .padding(.bottom, DesignBook.Spacing.sm)
    }

    var multiDeviceModes: some View {
        GlassContainer(spacing: DesignBook.Spacing.xs) {
            VStack(spacing: DesignBook.Spacing.md) {
                NavigationCard(
                    icon: "dot.radiowaves.left.and.right",
                    title: localized("home.nearbyGame"),
                    description: localized("home.nearbyGame.description")
                ) {
                    navigator.present(.localFlow)
                }
                .accessibilityIdentifier("home.playNearby")

                NavigationCard(
                    icon: "globe",
                    title: localized("home.onlineGame"),
                    description: localized("home.onlineGame.description")
                ) {
                    navigator.present(.onlineFlow)
                }
                .accessibilityIdentifier("home.playOnline")
            }
        }
        .paddingHorizontalDefault()
    }

    @ViewBuilder
    var overwriteDialogActions: some View {
        Button(localized("home.newGame.overwrite.confirm"), role: .destructive) {
            discardSavedGame()
            navigator.present(.teamSetup)
        }
        if let savedGame {
            Button(localized("home.newGame.overwrite.resume")) {
                navigator.present(.resumeGame(savedGame))
            }
        }
        Button(localized("common.buttons.cancel"), role: .cancel) {}
    }

    @ToolbarContentBuilder
    var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .trailingAction) {
            Button {
                navigator.push(.settings)
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(Text(localized("common.buttons.settings")))
            .help(localized("common.buttons.settings"))
        }
    }

    /// Starting a game replaces the saved one, so ask first.
    func startPassAndPlay() {
        if savedGame == nil {
            navigator.present(.teamSetup)
        } else {
            isOverwriteConfirmationPresented = true
        }
    }

    var instructions: [(icon: String, text: String)] {
        [
            (icon: "person.2.fill", text: localized("home.instructions.createTeams")),
            (icon: "text.bubble.fill", text: localized("home.instructions.addWords")),
            (icon: "shuffle.circle.fill", text: localized("home.instructions.randomize")),
            (icon: "1.circle.fill", text: localized("home.instructions.round1")),
            (icon: "2.circle.fill", text: localized("home.instructions.round2")),
            (icon: "3.circle.fill", text: localized("home.instructions.round3")),
            (icon: "trophy.fill", text: localized("home.instructions.winner")),
        ]
    }
}

// MARK: - Saved game
private extension HomeView {
    func loadSavedGame() async {
        guard navigator.presentedPage == nil else { return }
        #if DEBUG
        if UITestConfiguration.consumeSavedGameReset() {
            await gameStore.clear()
        }
        #endif
        let state = await gameStore.load()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.smooth) {
            savedGame = state.flatMap { $0.phase.isInProgress ? $0 : nil }
        }
    }

    func discardSavedGame() {
        discardedGames += 1
        withAnimation(reduceMotion ? nil : DesignBook.Motion.smooth) {
            savedGame = nil
        }
        Task {
            await gameStore.clear()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(Navigator())
}
