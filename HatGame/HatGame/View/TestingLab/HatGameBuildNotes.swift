#if DEBUG
import Navigation
import SwiftUI
import TestingLab

/// The changes to try in this build, newest first. Rewrite it for every build
/// handed over for testing, so it lists only what that build adds. English
/// only: the lab is for whoever tests the build.
struct HatGameBuildNotes {
    let routes: LabRoutes

    var current: [BuildNote] {
        [history, recap, recording]
    }
}

// MARK: - Notes
private extension HatGameBuildNotes {
    var history: BuildNote {
        BuildNote(
            commit: "HEAD",
            title: lab("History of every game"),
            howToTest: lab("""
                Tap the clock on Home. History lists the games played on this phone by month, under games, \
                words guessed, and time played. Long-press a game to preview it, share it, or delete it; swipe \
                it to delete. The trash clears everything. The lab adds sample games when History is empty.
                """),
            systemImage: "clock.arrow.circlepath",
            color: .indigo
        ) { routes.history() }
    }

    var recap: BuildNote {
        BuildNote(
            commit: "HEAD",
            title: lab("A recap for each game"),
            howToTest: lab("""
                Open a game: the winner and margin, the scoreboard by round, the best explainer and best turn, \
                what each player explained, every turn with its words, and the settings it used. Share sends \
                the standings as text. Online and nearby games show scores only. Try Georgian and dark mode.
                """),
            systemImage: "trophy",
            color: .orange
        ) { routes.history(openingSample: true) }
    }

    var recording: BuildNote {
        BuildNote(
            commit: "HEAD",
            title: lab("Games are kept when they end"),
            howToTest: lab("""
                Play a Quick Game to the end, or score a word and end it from the Close button: it appears at \
                the top of History, an ended game marked Ended early. A game ended before anyone scored isn't \
                kept. Online and nearby games are kept from their results screen.
                """),
            systemImage: "checkmark.seal",
            color: .green
        ) { routes.quickGame() }
    }
}

// MARK: - Text
/// The lab's words as they are, kept out of the String Catalog: a literal
/// resource would be extracted and wait for a Georgian translation nobody reads.
func lab(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource(String.LocalizationValue(text))
}
#endif
