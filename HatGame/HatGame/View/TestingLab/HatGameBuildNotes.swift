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
        [noSkip, haptics, copy, glass, colour, behaviour, accessibility]
    }
}

// MARK: - Notes
private extension HatGameBuildNotes {
    var noSkip: BuildNote {
        BuildNote(
            commit: "d52bf4f",
            title: lab("The draw and the shuffle play through"),
            howToTest: lab("""
                Pick for Us, then Start Game: neither the word draw nor the shuffle says Tap to Skip, and a \
                tap no longer cuts them short. Each still plays in full only the first time in a session.
                """),
            systemImage: "play.circle",
            color: .purple
        ) { routes.passAndPlay() }
    }

    var haptics: BuildNote {
        BuildNote(
            commit: "a1bb094",
            title: lab("Haptics follow the constitution"),
            howToTest: lab("""
                Every change you make is felt once: Got It and adding a word or player tap like a success, \
                Skip and any pick tick, a confirmed delete or end warns, a refused word buzzes. The countdown, \
                time-up, starting a turn, and results screens no longer vibrate. Settings ▸ Haptics silences all.
                """),
            systemImage: "iphone.radiowaves.left.and.right",
            color: .pink
        ) { routes.quickGame() }
    }

    var copy: BuildNote {
        BuildNote(
            commit: "f047874",
            title: lab("Calmer copy, symbols for emoji"),
            howToTest: lab("""
                No exclamation marks anywhere, in English or Georgian. Next Team shows a target symbol, \
                round results number the places, and Settings ▸ Language lists its choices with glyphs.
                """),
            systemImage: "text.quote",
            color: .orange
        ) { routes.quickGame() }
    }

    var glass: BuildNote {
        BuildNote(
            commit: "a5a98d3",
            title: lab("Flows rise from the bottom; glass only on controls"),
            howToTest: lab("""
                Pass and Play, Play Nearby, and Play Online slide up instead of zooming out of their button. \
                How to Play is an opaque card again. With a saved game, Resume is the one blue button. In a \
                lobby, long-press a team to delete it; Add Team is a glass capsule.
                """),
            systemImage: "square.on.square",
            color: .blue
        ) { routes.passAndPlay() }
    }

    var colour: BuildNote {
        BuildNote(
            commit: "8f1c183",
            title: lab("The accent is rare"),
            howToTest: lab("""
                Blue stays on the main button, toggles, checkmarks, and progress; card headers, menus, links, \
                and small controls draw in the text colour. Counts roll in place, and small numbers share one badge.
                """),
            systemImage: "paintpalette",
            color: .indigo
        ) { routes.passAndPlay() }
    }

    var behaviour: BuildNote {
        BuildNote(
            commit: "bae66b4",
            title: lab("Try Again, and what leaves the device"),
            howToTest: lab("""
                Turn the network off and join or create a room: the alert offers Try Again. Play Online and \
                Feedback say what they send. Join Nearby explains Local Network and opens Settings.
                """),
            systemImage: "arrow.clockwise",
            color: .teal
        ) { routes.playOnline() }
    }

    var accessibility: BuildNote {
        BuildNote(
            commit: "ae2ec87",
            title: lab("Bigger text, clearer cards"),
            howToTest: lab("""
                At the largest text size, settings rows and Starting Team stack instead of clipping, and the \
                turn scrolls. The pause button shows the clock. With Increase Contrast, cards gain an edge. \
                Team sheets now open from the flow, so swipe a team to edit or delete it.
                """),
            systemImage: "textformat.size",
            color: .green
        ) { routes.passAndPlay() }
    }
}

// MARK: - Text
/// The lab's words as they are, kept out of the String Catalog: a literal
/// resource would be extracted and wait for a Georgian translation nobody reads.
func lab(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource(String.LocalizationValue(text))
}
#endif
