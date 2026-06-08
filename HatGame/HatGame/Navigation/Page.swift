//
//  Page+App.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Navigation
import SwiftUI

// MARK: - App Pages
extension Page {
    static var home: Page<HomeView> {
        Page<HomeView>(id: "home") {
            HomeView()
        }
    }

    static var settings: Page<SettingsView> {
        Page<SettingsView>(id: "settings") {
            SettingsView()
        }
    }

    static var developerInfo: Page<DeveloperInfoView> {
        Page<DeveloperInfoView>(id: "developerInfo") {
            DeveloperInfoView()
        }
    }

    static var feedback: Page<FeedbackView> {
        Page<FeedbackView>(id: "feedback") {
            FeedbackView()
        }
    }

    static var appIconSelection: Page<AppIconSelectionView> {
        Page<AppIconSelectionView>(id: "appIconSelection") {
            AppIconSelectionView()
        }
    }

    static var defaultsSettings: Page<DefaultsSettingsView> {
        Page<DefaultsSettingsView>(id: "defaultsSettings") {
            DefaultsSettingsView()
        }
    }

    static var teamSetup: Page<GameFlowView> {
        Page<GameFlowView>(id: "teamSetup") {
            GameFlowView()
        }
    }

    static var wordSettings: Page<WordSettingsView> {
        Page<WordSettingsView>(id: "wordSettings") {
            WordSettingsView()
        }
    }

    static var timerSettings: Page<TimerSettingsView> {
        Page<TimerSettingsView>(id: "timerSettings") {
            TimerSettingsView()
        }
    }

    static var wordSource: Page<WordSourceView> {
        Page<WordSourceView>(id: "wordSource") {
            WordSourceView()
        }
    }

    static var wordInput: Page<WordInputView> {
        Page<WordInputView>(id: "wordInput") {
            WordInputView()
        }
    }

    static var wordGeneration: Page<WordGenerationView> {
        Page<WordGenerationView>(id: "wordGeneration") {
            WordGenerationView()
        }
    }

    static var randomization: Page<RandomizationView> {
        Page<RandomizationView>(id: "randomization") {
            RandomizationView()
        }
    }

    static func play(round: GameRound) -> Page<GameView> {
        Page<GameView>(id: "play-\(round.rawValue)") {
            GameView(round: round)
        }
    }

    static func teamTurnResults(
        guessedWords: [Word],
        completionReason: PlayCompletionReason
    ) -> Page<TeamTurnResultsView> {
        Page<TeamTurnResultsView>(id: "teamTurnResults-\(guessedWords.hashValue)") {
            TeamTurnResultsView(guessedWords: guessedWords, completionReason: completionReason)
        }
    }

    static func nextTeam(round: GameRound, team: Team) -> Page<NextTeamView> {
        Page<NextTeamView>(id: "nextTeam-\(round.rawValue)-\(team.id)") {
            NextTeamView(round: round, team: team)
        }
    }

    static var roundResults: Page<ResultsView> {
        Page<ResultsView>(id: "roundResults") {
            ResultsView()
        }
    }

    static var finalResults: Page<ResultsView> {
        Page<ResultsView>(id: "finalResults") {
            ResultsView()
        }
    }

    // MARK: - Online Pages
    static var onlineFlow: Page<OnlineFlowView> {
        Page<OnlineFlowView>(id: "onlineFlow") {
            OnlineFlowView()
        }
    }

    static var onlineMenu: Page<OnlineMenuView> {
        Page<OnlineMenuView>(id: "onlineMenu") {
            OnlineMenuView()
        }
    }

    static var createRoom: Page<RoomCreationView> {
        Page<RoomCreationView>(id: "createRoom") {
            RoomCreationView()
        }
    }

    static var joinRoom: Page<RoomJoinView> {
        Page<RoomJoinView>(id: "joinRoom") {
            RoomJoinView()
        }
    }

    /// The "session" destination once a player has joined or created a room.
    /// Internally it's `OnlineGameFlowView`, which renders the lobby while
    /// waiting and swaps in the gameplay views as the room status / game
    /// phase progresses.
    static func roomLobby(roomCode: String) -> Page<OnlineGameFlowView> {
        Page<OnlineGameFlowView>(id: "roomLobby-\(roomCode)") {
            OnlineGameFlowView()
        }
    }

    // MARK: - Local (Multipeer) Pages
    static var localFlow: Page<LocalFlowView> {
        Page<LocalFlowView>(id: "localFlow") {
            LocalFlowView()
        }
    }

    static var localHostSetup: Page<LocalHostSetupView> {
        Page<LocalHostSetupView>(id: "localHostSetup") {
            LocalHostSetupView()
        }
    }

    static var localBrowser: Page<LocalRoomBrowser> {
        Page<LocalRoomBrowser>(id: "localBrowser") {
            LocalRoomBrowser()
        }
    }

    static func localSession(roomCode: String) -> Page<LocalSessionView> {
        Page<LocalSessionView>(id: "localSession-\(roomCode)") {
            LocalSessionView()
        }
    }
}
