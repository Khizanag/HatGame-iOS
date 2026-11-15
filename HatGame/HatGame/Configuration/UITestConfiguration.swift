//
//  UITestConfiguration.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 08.06.26.
//

import Navigation
import SwiftUI

// MARK: - UI test deep linking
extension View {
    /// Deep-links the app to the screen named by the `-uiTestScreen` launch
    /// argument so the snapshot harness can land on any screen directly.
    /// A no-op in release builds and whenever the argument is absent.
    func uiTestDeepLink(_ navigator: Navigator) -> some View {
        #if DEBUG
        return task {
            try? await Task.sleep(for: .milliseconds(120))
            UITestConfiguration.deepLink(using: navigator)
        }
        #else
        return self
        #endif
    }
}

#if DEBUG
// MARK: - UI test configuration
/// Reads the launch arguments the snapshot harness passes through `simctl`.
/// Compiled only into DEBUG builds — never shipped.
enum UITestConfiguration {
    static var screen: String? {
        value(for: "-uiTestScreen")
    }

    static var colorScheme: AppColorScheme? {
        value(for: "-uiTestColorScheme").flatMap(AppColorScheme.init(rawValue:))
    }

    static var disablesAnimations: Bool {
        CommandLine.arguments.contains("-uiTestDisableAnimations")
    }

    private static var hasResetSavedGame = false

    /// True once per launch when `-uiTestResetState` asks to start without a
    /// saved game; the relaunch half of a restore test omits the flag.
    @MainActor
    static func consumeSavedGameReset() -> Bool {
        guard CommandLine.arguments.contains("-uiTestResetState"), !hasResetSavedGame else { return false }
        hasResetSavedGame = true
        return true
    }

    @MainActor
    static func deepLink(using navigator: Navigator) {
        guard navigator.navigationPath.isEmpty else { return }
        switch screen {
        case "settings":
            navigator.push(.settings)
        case "defaults":
            navigator.push(.defaultsSettings)
        case "appIcon":
            navigator.push(.appIconSelection)
        case "game":
            navigator.present(.uiTestGame)
        default:
            break
        }
    }

    private static func value(for flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard
            let index = arguments.firstIndex(of: flag),
            index + 1 < arguments.count
        else {
            return nil
        }
        return arguments[index + 1]
    }
}
// MARK: - UI test game
extension GameConfiguration {
    /// Two teams of two and a two-word hat: the shortest game that still
    /// exercises turns, rotation, and every round.
    static var uiTestGame: GameConfiguration {
        let alphaId = UUID()
        let betaId = UUID()
        return GameConfiguration(
            wordsPerPlayer: 1,
            roundDuration: 60,
            isSkippingEnabled: true,
            teams: [
                Team(
                    id: alphaId,
                    name: "Alpha",
                    players: [Player(name: "Ann", teamId: alphaId), Player(name: "Ben", teamId: alphaId)],
                    color: TeamDefaultColorGenerator.defaultColors[0]
                ),
                Team(
                    id: betaId,
                    name: "Beta",
                    players: [Player(name: "Cat", teamId: betaId), Player(name: "Dan", teamId: betaId)],
                    color: TeamDefaultColorGenerator.defaultColors[1]
                ),
            ],
            words: [Word(text: "apple"), Word(text: "river")]
        )
    }
}

// MARK: - UI test pages
extension Page {
    static var uiTestGame: Page<GameFlowView> {
        Page<GameFlowView>(id: "uiTestGame") {
            GameFlowView(launch: .uiTestGame)
        }
    }
}
#endif
