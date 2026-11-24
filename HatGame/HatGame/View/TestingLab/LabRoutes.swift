#if DEBUG
import Navigation
import SwiftUI

/// Where the lab's notes and shortcuts go, on the app's root navigator. A
/// pushed screen first closes any flow in front of Home, so it's the one that
/// shows; a flow opens over whatever is there.
@MainActor
struct LabRoutes {
    let navigator: Navigator

    func push<Content: View>(_ page: Page<Content>) {
        navigator.presentedPage = nil
        navigator.navigationPath = [page.eraseToAnyPage()]
    }

    /// Leaves any pushed screens in place: popping them while a flow zooms
    /// open makes UIKit's zoom transition lose its source and crash.
    func present<Content: View>(_ page: Page<Content>) {
        navigator.present(page)
    }

    func passAndPlay() {
        present(.teamSetup)
    }

    func playNearby() {
        present(.localFlow)
    }

    func playOnline() {
        present(.onlineFlow)
    }

    /// Home with the How to Play sheet open. Waits for the lab's own sheet to
    /// leave, since one host can't present two sheets at once.
    func howToPlay() {
        navigator.presentedPage = nil
        navigator.navigationPath = []
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            navigator.presentSheet(.howToPlay)
        }
    }

    /// A started two-team, two-word game: the shortest way into a turn.
    func quickGame() {
        present(.uiTestGame)
    }
}
#endif
