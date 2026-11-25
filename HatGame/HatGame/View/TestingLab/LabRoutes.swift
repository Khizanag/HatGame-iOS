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

    /// History, after adding the sample games when it has none to show.
    func history(openingSample: Bool = false) {
        let history = GameHistory.shared
        Task {
            await history.load()
            if history.records.isEmpty {
                GameRecord.samples().reversed().forEach(history.record)
            }
            await history.waitForPendingWrites()
            navigator.presentedPage = nil
            var path = [Page<HistoryView>.history.eraseToAnyPage()]
            if openingSample, let record = history.records.first {
                path.append(Page<GameRecapView>.gameRecap(record.id).eraseToAnyPage())
            }
            navigator.navigationPath = path
        }
    }

    /// A started two-team, two-word game: the shortest way into a turn.
    func quickGame() {
        present(.uiTestGame)
    }
}
#endif
