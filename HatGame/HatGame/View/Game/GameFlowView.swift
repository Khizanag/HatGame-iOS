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
        switch launch {
        case .newGame:
            manager = GameManager(
                configuration: appConfiguration.isTestMode
                    ? .mockForTesting
                    : GameConfiguration(defaults: appConfiguration.gameDefaults)
            )
        case .resume(let state):
            manager = GameManager(restoring: state, defaults: appConfiguration.gameDefaults)
            navigator.navigationPath = [Page<GameLoopView>.gameLoop.eraseToAnyPage()]
        #if DEBUG
        case .uiTestGame:
            manager = GameManager(configuration: .uiTestGame)
            navigator.navigationPath = [Page<GameLoopView>.gameLoop.eraseToAnyPage()]
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
