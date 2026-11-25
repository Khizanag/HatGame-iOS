//
//  GameFlowView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Navigation
import SwiftUI

struct GameFlowView: View {
    /// How the flow opens.
    enum Launch {
        /// Fresh setup, starting from team setup.
        case newGame
        /// A saved game, straight into its game loop.
        case resume(GameState)
        #if DEBUG
        /// A tiny started game for UI tests.
        case uiTestGame
        /// The UI test teams on Fill the Hat, with an empty hat.
        case uiTestFillHat
        /// The UI test teams and words, choosing who starts.
        case uiTestRandomization
        #endif
    }

    @Environment(\.dismiss) private var dismiss
    @State private var gameManager: GameManager
    @State private var gameNavigator: Navigator

    private let launch: Launch

    init(launch: Launch = .newGame) {
        self.launch = launch
        let appConfiguration = AppConfiguration.shared
        let navigator = Navigator()
        let manager: GameManager
        let history = GameHistory.shared
        switch launch {
        case .newGame:
            manager = GameManager(
                configuration: appConfiguration.isTestMode
                    ? .mockForTesting
                    : GameConfiguration(defaults: appConfiguration.gameDefaults),
                recorder: history
            )
        case .resume(let state):
            manager = GameManager(restoring: state, defaults: appConfiguration.gameDefaults, recorder: history)
            navigator.navigationPath = [Page<GameLoopView>.gameLoop.eraseToAnyPage()]
        #if DEBUG
        case .uiTestGame:
            manager = GameManager(configuration: .uiTestGame, recorder: history)
            navigator.navigationPath = [Page<GameLoopView>.gameLoop.eraseToAnyPage()]
        case .uiTestFillHat:
            let configuration = GameConfiguration.uiTestGame
            configuration.words = []
            configuration.wordsPerPlayer = 10
            manager = GameManager(configuration: configuration)
            navigator.navigationPath = [Page<WordSourceView>.wordSource.eraseToAnyPage()]
        case .uiTestRandomization:
            manager = GameManager(configuration: .uiTestGame)
            navigator.navigationPath = [Page<RandomizationView>.randomization.eraseToAnyPage()]
        #endif
        }
        _gameManager = State(initialValue: manager)
        _gameNavigator = State(initialValue: navigator)
    }

    var body: some View {
        NavigationStack(path: Bindable(gameNavigator).navigationPath) {
            TeamSetupView()
                .navigationDestination(for: AnyPage.self) { page in
                    page.view()
                        .environment(gameManager)
                        .environment(gameManager.engine)
                        .environment(gameNavigator)
                }
        }
        // The flow presents every sheet its screens ask for (constitution article 13).
        .sheet(item: Bindable(gameNavigator).presentedSheet) { page in
            page.view()
                .environment(gameManager)
                .environment(gameManager.engine)
                .environment(gameNavigator)
                .environment(\.showsScreenBackground, false)
                .controlTint()
        }
        .controlTint()
        .environment(gameManager)
        .environment(gameManager.engine)
        .environment(gameNavigator)
        // Where the flow is a sheet (macOS), a stray dismiss mustn't drop the teams.
        .interactiveDismissDisabled(!gameManager.configuration.teams.isEmpty)
        .onReceive(gameNavigator.pleaseDismissViewPublisher) {
            dismiss()
        }
        .task {
            await startUITestGameIfNeeded()
        }
        #if DEBUG
        // Outside the flow's own navigator: the lab routes on the app's.
        .hatGameTestingLab()
        #endif
    }
}

// MARK: - Private
private extension GameFlowView {
    /// Started here rather than in `init`: SwiftUI may build this view more
    /// than once, and starting a game saves it.
    func startUITestGameIfNeeded() async {
        #if DEBUG
        guard case .uiTestGame = launch, gameManager.engine.phase == .setup else { return }
        gameManager.startGame(startingTeamIndex: 0)
        #endif
    }
}
