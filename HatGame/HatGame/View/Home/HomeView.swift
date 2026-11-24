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
            .toolbar { homeToolbar }
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
                .opacity(DesignBook.Opacity.nearlyOpaque)
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
                Spacer().frame(height: DesignBook.Spacing.xl)
            }
        }
        .actionBar {
            actionButtons
        }
        .onAppear {
            guard !reduceMotion else { return }
            #if DEBUG
            if UITestConfiguration.disablesAnimations { return }
            #endif
            withAnimation(DesignBook.Motion.heroLoop) {
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
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignBook.Spacing.lg)
            }
        }
    }

    var heroIcon: some View {
        ZStack {
            HeroGlow(.hero, opacity: DesignBook.Opacity.glow)

            // Inner glass disc.
            Circle()
                .fill(DesignBook.Color.Background.card)
                .frame(width: DesignBook.Size.heroDisc, height: DesignBook.Size.heroDisc)
                .overlay {
                    Circle()
                        .strokeBorder(DesignBook.Gradient.heroRim, lineWidth: DesignBook.Size.strokeRegular)
                }
                .shadow(.large)

            Text(verbatim: "🎩")
                .font(DesignBook.IconFont.emojiLarge)
                .offset(y: floatOffset)
                .accessibilityHidden(true)
        }
    }

    var floatOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        let amplitude = DesignBook.Size.heroFloatAmplitude
        return isHeroFloating ? -amplitude : amplitude
    }

    func resumeCard(for state: GameState) -> some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.md) {
                    CircularIconContainer(
                        icon: "hourglass",
                        size: DesignBook.Size.largeIconSize,
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
    var homeToolbar: some ToolbarContent {
        ToolbarItem(placement: .trailingAction) {
            Button {
                navigator.push(.rules)
            } label: {
                Label(localized("home.howToPlay.title"), systemImage: "questionmark.circle")
            }
            .help(localized("home.howToPlay.title"))
            .accessibilityIdentifier("home.howToPlay")
        }
        ToolbarItem(placement: .trailingAction) {
            Button {
                navigator.push(.settings)
            } label: {
                Label(localized("common.buttons.settings"), systemImage: "gearshape")
            }
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
