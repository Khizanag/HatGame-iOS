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
        [liquidGlass, heroNumbers, appIconCards, saveAndExit, leaveRoom, haptics, settings]
    }
}

// MARK: - Notes
private extension HatGameBuildNotes {
    var liquidGlass: BuildNote {
        BuildNote(
            commit: "9e391a1",
            title: lab("Liquid Glass controls"),
            howToTest: lab("""
                Pass and Play: Add Team ▸ name suggestions and shuffle; Add Words ▸ Auto-fill, then tap \
                the word field and watch Add Word melt into the round button; Next Team ▸ shuffle and \
                Standings (a glass sheet at half height).
                """),
            systemImage: "drop.fill",
            color: .cyan
        ) { routes.passAndPlay() }
    }

    var heroNumbers: BuildNote {
        BuildNote(
            commit: "450e0ef",
            title: lab("Setup numbers roll without clipping"),
            howToTest: lab("""
                Pass and Play ▸ Continue, then tap + and − on Words and Timer: digits roll in and out \
                whole, including 10 → 5.
                """),
            systemImage: "textformat.123",
            color: .purple
        ) { routes.passAndPlay() }
    }

    var appIconCards: BuildNote {
        BuildNote(
            commit: "85fb0f6",
            title: lab("App Icon cards keep their corners"),
            howToTest: lab("Settings ▸ App Icon: the selected card's border is round on every corner."),
            systemImage: "app.badge.checkmark",
            color: .indigo
        ) { routes.push(.appIconSelection) }
    }

    var saveAndExit: BuildNote {
        BuildNote(
            commit: "1d4ef30",
            title: lab("Save and Exit"),
            howToTest: lab("""
                In a game, tap End Game ▸ Save and Exit: Home offers Resume, and the turn comes back paused.
                """),
            systemImage: "tray.and.arrow.down.fill",
            color: .orange
        ) { routes.quickGame() }
    }

    var leaveRoom: BuildNote {
        BuildNote(
            commit: "b6640d5",
            title: lab("Leaving a room tells everyone"),
            howToTest: lab("""
                Host a Nearby room on one device, join on another, then Leave on either: the other side \
                updates at once. There is no Back button inside a room.
                """),
            systemImage: "door.left.hand.open",
            color: .blue
        ) { routes.playNearby() }
    }

    var haptics: BuildNote {
        BuildNote(
            commit: "dd5ca82",
            title: lab("Haptics can be turned off"),
            howToTest: lab("""
                Default Game Settings ▸ Haptics. With it on, only game moments vibrate: Got It, Skip, the \
                last seconds, and time up.
                """),
            systemImage: "iphone.radiowaves.left.and.right",
            color: .pink
        ) { routes.push(.defaultsSettings) }
    }

    var settings: BuildNote {
        BuildNote(
            commit: "25e822c",
            title: lab("Settings is a native list"),
            howToTest: lab("Settings: a large title, full-row pickers, and the real icons in App Icon."),
            systemImage: "gearshape.fill",
            color: .gray
        ) { routes.push(.settings) }
    }
}

// MARK: - Text
/// The lab's words as they are, kept out of the String Catalog: a literal
/// resource would be extracted and wait for a Georgian translation nobody reads.
func lab(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource(String.LocalizationValue(text))
}
#endif
