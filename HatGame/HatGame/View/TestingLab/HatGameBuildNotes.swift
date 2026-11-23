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
        [
            glassCards, hatWords, hatLanding, startingTeam, fillTheHat, skipPenalty, toolbarSymbols, setupFixes,
            onlineFixes, liquidGlass, heroNumbers, appIconCards, saveAndExit, leaveRoom, haptics, settings,
        ]
    }
}

// MARK: - Notes
private extension HatGameBuildNotes {
    var glassCards: BuildNote {
        BuildNote(
            commit: "03f4bf7",
            title: lab("Every tappable card is Liquid Glass"),
            howToTest: lab("""
                Home: Play Nearby, Play Online, and How to Play are glass and shimmer under your finger. \
                The same glass, tinted and ringed when picked, on Fill the Hat's two tiles, Starting Team, \
                the explainer picker, App Icon, the team color card, and nearby rooms.
                """),
            systemImage: "square.on.square",
            color: .blue
        ) { routes.passAndPlay() }
    }

    var hatWords: BuildNote {
        BuildNote(
            commit: "41ac46d",
            title: lab("Real words fly into the hat"),
            howToTest: lab("""
                Open Fill the Hat: the chips are short words from the word list in the app's language, \
                not players' names, and they barely repeat. Switch the language to see Georgian ones.
                """),
            systemImage: "text.bubble",
            color: .teal
        ) { routes.passAndPlay() }
    }

    var hatLanding: BuildNote {
        BuildNote(
            commit: "b9745bb",
            title: lab("The hat sits centered and bobs as each word goes in"),
            howToTest: lab("""
                On Fill the Hat the upturned hat sits in the middle of its circle, and it swells the \
                moment a name or word disappears into it. Start Game on Starting Team: the slips hop \
                over the brim and drop in one by one, with a bob for each.
                """),
            systemImage: "hat.widebrim.fill",
            color: .indigo
        ) { routes.passAndPlay() }
    }

    var startingTeam: BuildNote {
        BuildNote(
            commit: "a1c2480",
            title: lab("A roulette for the starting team, and a real shuffle"),
            howToTest: lab("""
                Fill the hat, then on Starting Team tap Randomize: the highlight spins round the teams, \
                slows, and the winner flips in with confetti. Start Game: blank slips swirl round the \
                upturned hat and get pulled in. Tap to skip still works.
                """),
            systemImage: "dice.fill",
            color: .pink
        ) { routes.passAndPlay() }
    }

    var fillTheHat: BuildNote {
        BuildNote(
            commit: "4ec939f",
            title: lab("Fill the Hat replaces two setup screens"),
            howToTest: lab("""
                Pass and Play ▸ teams ▸ Continue ▸ Timer ▸ Continue: one screen sets words per player and \
                where the words come from. The total rolls as you step and words fly into the upturned hat. \
                Continue says Write Words or Draw Words.
                """),
            systemImage: "hat.widebrim.fill",
            color: .purple
        ) { routes.passAndPlay() }
    }

    var skipPenalty: BuildNote {
        BuildNote(
            commit: "e9d76e4",
            title: lab("Skipping costs a point"),
            howToTest: lab("""
                Start a game and tap Skip −1: the turn score drops below zero and turns orange; Turn \
                Results shows the net points with what was guessed and skipped. Pass and Play ▸ Timer \
                Settings (and Settings ▸ Default Game Settings, and the room forms) set it from None to −3.
                """),
            systemImage: "minus.circle",
            color: .orange
        ) { routes.quickGame() }
    }

    var toolbarSymbols: BuildNote {
        BuildNote(
            commit: "ac09f99",
            title: lab("Toolbar symbols instead of words"),
            howToTest: lab("""
                In a game, between turns: Standings is a list symbol, and the round × closes the game — it \
                still asks Save and Exit or End Game. Give Up stays a word during a turn.
                """),
            systemImage: "list.number",
            color: .teal
        ) { routes.quickGame() }
    }

    var setupFixes: BuildNote {
        BuildNote(
            commit: "d24de3d",
            title: lab("Teams of 2 to 6, and setup that keeps its words"),
            howToTest: lab("""
                Add Team ▸ Add Player for a third seat. Then go back and forth through setup: edit a team, \
                switch between Pick for me and Enter manually, lower words per player — the hat stays right. \
                Finish a game and tap Play Again twice in a row.
                """),
            systemImage: "person.3.fill",
            color: .green
        ) { routes.passAndPlay() }
    }

    var onlineFixes: BuildNote {
        BuildNote(
            commit: "d1596e3",
            title: lab("Multiplayer turns start on a fresh word"),
            howToTest: lab("""
                In an online or nearby game, let time run out: the next team gets a different word, not the \
                one just explained. Starting a room locks the teams.
                """),
            systemImage: "person.2.wave.2.fill",
            color: .blue
        ) { routes.playNearby() }
    }

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
                In a game, tap × ▸ Save and Exit: Home offers Resume, and the turn comes back paused.
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
