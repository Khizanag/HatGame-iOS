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
    @State private var hasEndedGame = false

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
                announceTimeUp(from: previous, to: phase)
            }
            .haptic(.warning, trigger: engine.phase) { old, new in
                old == .playing && new == .turnResults && engine.state.turn?.endReason == .gaveUp
            }
            .haptic(.warning, trigger: hasEndedGame) { _, new in new }
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
                    points: engine.state.turnPoints,
                    skippedCount: penalizedSkips,
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

    /// Skips that cost points this turn; free skips aren't worth reporting.
    var penalizedSkips: Int {
        engine.state.settings.skipPenalty > 0 ? engine.state.turn?.skippedCount ?? 0 : 0
    }

    var phaseTransition: AnyTransition {
        reduceMotion ? .opacity : .push(from: .trailing)
    }
}

// MARK: - Leaving the game
private extension GameLoopView {
    /// The flow's standard Close, offered only between turns (a turn has its
    /// own Give Up). Mid-game it asks first, offering Save and Exit; once
    /// the game is over it simply returns to Home.
    @ToolbarContentBuilder
    var leavingToolbar: some ToolbarContent {
        if engine.phase == .nextTeam || engine.phase == .turnResults {
            CloseToolbarItem(
                accessibilityLabel: localized("game.endGame.button"),
                accessibilityIdentifier: "game.endGame"
            ) {
                isEndGameConfirmationPresented = true
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
        hasEndedGame = true
        engine.abandon()
        returnToMain()
    }

    /// Waits for the save (or the clear) to land first, so Home's resume card
    /// never reads the file before it. Dismisses without popping the stack,
    /// which would flash Team Setup as the flow closes.
    func returnToMain() {
        Task {
            await engine.waitForPendingWrites()
            navigator.dismiss()
        }
    }
}

// MARK: - Feedback
private extension GameLoopView {
    /// Announces a turn the clock ended, since time-up is a time-critical
    /// change. It plays no haptic: the person didn't make it.
    func announceTimeUp(from previous: GameState.Phase, to phase: GameState.Phase) {
        guard previous == .playing, phase == .turnResults else { return }
        switch engine.state.turn?.endReason {
        case .timeExpired, nil:
            AccessibilityNotification.Announcement(localized("game.turnResults.timeUp")).post()
        case .allWordsGuessed, .gaveUp:
            break
        }
    }
}
