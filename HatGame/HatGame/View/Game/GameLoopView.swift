//
//  GameLoopView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import Navigation
import SwiftUI

/// The whole single-device game loop as one page: it switches between Next
/// Team, the turn, Turn Results, and Final Results as the engine's phase
/// changes, instead of pushing pages per turn. Back navigation is hidden (which
/// also disables swipe-back), so the loop can only move forward.
struct GameLoopView: View {
    @Environment(GameEngine.self) private var engine
    @Environment(Navigator.self) private var navigator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isEndGameConfirmationPresented = false

    var body: some View {
        phaseContent
            .navigationBarBackButtonHidden()
            .interactiveDismissDisabled()
            .toolbar { leavingToolbar }
            .confirmationDialog(
                localized("game.endGame.title"),
                isPresented: $isEndGameConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(localized("game.endGame.saveAndExit"), action: saveAndExit)
                    .accessibilityIdentifier("game.endGame.saveAndExit")
                Button(localized("game.endGame.confirm"), role: .destructive, action: endGame)
                    .accessibilityIdentifier("game.endGame.confirm")
                Button(localized("common.buttons.cancel"), role: .cancel) {}
            } message: {
                Text(localized("game.endGame.message"))
            }
            .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: engine.phase)
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                engine.handleLeavingForeground()
            }
            .onChange(of: engine.phase) { previous, phase in
                playTurnEndFeedback(from: previous, to: phase)
            }
    }
}

// MARK: - Content
private extension GameLoopView {
    @ViewBuilder
    var phaseContent: some View {
        switch engine.phase {
        case .nextTeam:
            if let team = engine.state.currentTeam {
                NextTeamView(round: engine.state.round, team: team)
                    .id(team.id)
                    .transition(phaseTransition)
            }
        case .playing:
            GameView()
                .transition(phaseTransition)
        case .turnResults:
            if let team = engine.state.currentTeam {
                TeamTurnResultsView(
                    team: team,
                    guessedWords: engine.state.turnGuessedWords,
                    completionReason: engine.state.turn?.endReason ?? .timeExpired
                )
                .transition(phaseTransition)
            }
        case .finished:
            ResultsView()
                .transition(phaseTransition)
        case .setup:
            Color.clear
                .setDefaultBackground()
        }
    }

    var phaseTransition: AnyTransition {
        reduceMotion ? .opacity : .push(from: .trailing)
    }
}

// MARK: - Leaving the game
private extension GameLoopView {
    /// Leaving mid-game is a deliberate act, so it lives behind a confirmation
    /// and only between turns — during a turn the clock has its own Give Up.
    /// Once the game is over, Close simply returns to Home.
    @ToolbarContentBuilder
    var leavingToolbar: some ToolbarContent {
        if engine.phase == .nextTeam || engine.phase == .turnResults {
            ToolbarItem(placement: .cancellationAction) {
                Button(localized("game.endGame.button")) {
                    isEndGameConfirmationPresented = true
                }
                .accessibilityIdentifier("game.endGame")
            }
        } else if engine.phase == .finished {
            CloseToolbarItem(action: returnToMain)
        }
    }

    /// Leaves the game as it is; it stays saved and Home offers to resume it.
    func saveAndExit() {
        engine.handleLeavingForeground()
        returnToMain()
    }

    func endGame() {
        DesignBook.Haptics.warning()
        engine.abandon()
        returnToMain()
    }

    func returnToMain() {
        navigator.dismissToRoot()
        navigator.dismiss()
    }
}

// MARK: - Feedback
private extension GameLoopView {
    /// Marks the end of a turn by feel, and — when the clock ran out —
    /// announces it, since the time-up is a time-critical change.
    func playTurnEndFeedback(from previous: GameState.Phase, to phase: GameState.Phase) {
        guard previous == .playing, phase == .turnResults else { return }
        switch engine.state.turn?.endReason {
        case .allWordsGuessed:
            DesignBook.Haptics.success()
        case .gaveUp:
            DesignBook.Haptics.rigid()
        case .timeExpired, nil:
            DesignBook.Haptics.warning()
            AccessibilityNotification.Announcement(localized("game.turnResults.timeUp")).post()
        }
    }
}
