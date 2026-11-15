//
//  GameLoopView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The whole single-device game loop as one page: it switches between Next
/// Team, the turn, Turn Results, and Final Results as the engine's phase
/// changes, instead of pushing pages per turn. Back navigation is hidden (which
/// also disables swipe-back), so the loop can only move forward.
struct GameLoopView: View {
    @Environment(GameEngine.self) private var engine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        phaseContent
            .navigationBarBackButtonHidden()
            .interactiveDismissDisabled()
            .animation(reduceMotion ? nil : DesignBook.Motion.smooth, value: engine.phase)
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                engine.handleLeavingForeground()
            }
            .onChange(of: engine.phase) { previous, phase in
                playTurnEndHaptics(from: previous, to: phase)
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

// MARK: - Feedback
private extension GameLoopView {
    func playTurnEndHaptics(from previous: GameState.Phase, to phase: GameState.Phase) {
        guard previous == .playing, phase == .turnResults else { return }
        switch engine.state.turn?.endReason {
        case .allWordsGuessed:
            DesignBook.Haptics.success()
        case .gaveUp:
            DesignBook.Haptics.rigid()
        case .timeExpired, nil:
            DesignBook.Haptics.error()
        }
    }
}
