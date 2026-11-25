#if DEBUG
import Navigation
import Networking
import SwiftUI
import TestingLab

/// Hat Game's own tools in the Testing Lab: a game to jump into, the
/// switches, how the app looks, the multiplayer setup, and any screen.
/// English only, like the lab itself.
struct HatGameLabSections: View {
    @Environment(\.closeTestingLab) private var closeTestingLab
    @Environment(Navigator.self) private var navigator

    @Bindable private var configuration = AppConfiguration.shared

    var body: some View {
        playSection
        historySection
        switchesSection
        lookSection
        multiplayerSection
        screensSection
    }
}

// MARK: - Sections
private extension HatGameLabSections {
    var routes: LabRoutes { LabRoutes(navigator: navigator) }

    var playSection: some View {
        Section {
            go("Start a Quick Game", "play.fill", .green) { routes.quickGame() }
            toggle("Test Mode", $configuration.isTestMode, "wrench.adjustable.fill", .orange)
        } header: {
            Text(verbatim: "Play")
        } footer: {
            Text(verbatim: "A quick game is two teams of two and a two-word hat, already started. "
                + "Test Mode fills Pass and Play with sample teams and words.")
        }
    }

    var historySection: some View {
        Section {
            go("Open History", "clock.arrow.circlepath", .indigo) { routes.history() }
            Button {
                GameRecord.samples().reversed().forEach(GameHistory.shared.record)
            } label: {
                LabRow(verbatim: "Add Sample Games", systemImage: "plus.square.on.square", color: .teal)
            }
            Button(role: .destructive) {
                GameHistory.shared.deleteAll()
            } label: {
                LabRow(verbatim: "Clear History", systemImage: "trash", color: .red)
            }
        } header: {
            Text(verbatim: "History")
        } footer: {
            Text(verbatim: "Sample games: a close game, three teams, a tie, one ended early, one online, one nearby.")
        }
    }

    var switchesSection: some View {
        Section {
            toggle("Haptics", $configuration.isHapticsEnabled, "iphone.radiowaves.left.and.right", .pink)
            toggle("Time's Up Sound", $configuration.isTimeUpSoundEnabled, "speaker.wave.2.fill", .green)
            toggle("Allow Skipping", $configuration.defaultSkippingEnabled, "arrow.uturn.forward", .orange)
            toggle("Allow Duplicate Words", $configuration.allowDuplicateWords, "doc.on.doc.fill", .purple)
            toggle("Right-Handed Layout", $configuration.isRightHanded, "hand.point.right.fill", .blue)
        } header: {
            Text(verbatim: "Switches")
        } footer: {
            Text(verbatim: "The same settings as in the app; new games start with them.")
        }
    }

    var lookSection: some View {
        Section {
            Picker(selection: $configuration.language) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Label(language.displayName, systemImage: language.systemImage).tag(language)
                }
            } label: {
                LabRow(verbatim: "Language", systemImage: "globe", color: .blue)
            }
            Picker(selection: $configuration.colorScheme) {
                ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                    Text(verbatim: scheme.displayName).tag(scheme)
                }
            } label: {
                LabRow(verbatim: "Appearance", systemImage: "circle.lefthalf.filled", color: .indigo)
            }
        } header: {
            Text(verbatim: "Look")
        } footer: {
            Text(verbatim: "Georgian is the language to check text that runs long.")
        }
    }

    var multiplayerSection: some View {
        Section {
            status(
                "Online",
                Networking.isConfigured ? "Firebase connected" : "Firebase not configured",
                "globe",
                .blue
            )
            status(
                "Nearby Service",
                "_\(LocalMultipeerService.serviceType)._tcp",
                "dot.radiowaves.left.and.right",
                .teal
            )
        } header: {
            Text(verbatim: "Multiplayer")
        } footer: {
            Text(verbatim: "Nearby needs two devices on the same network; online needs four players to start a game.")
        }
    }

    var screensSection: some View {
        Section {
            go("Pass and Play", "person.2.fill", .green) { routes.passAndPlay() }
            go("Play Nearby", "dot.radiowaves.left.and.right", .teal) { routes.playNearby() }
            go("Play Online", "globe", .blue) { routes.playOnline() }
            AllScreens([
                LabDestination(title: "Pass and Play", systemImage: "person.2.fill", color: .green) {
                    routes.passAndPlay()
                },
                LabDestination(title: "Play Nearby", systemImage: "dot.radiowaves.left.and.right", color: .teal) {
                    routes.playNearby()
                },
                LabDestination(title: "Play Online", systemImage: "globe", color: .blue) {
                    routes.playOnline()
                },
                LabDestination(title: "Settings", systemImage: "gearshape.fill", color: .gray) {
                    routes.push(.settings)
                },
                LabDestination(title: "Default Game Settings", systemImage: "slider.horizontal.3", color: .orange) {
                    routes.push(.defaultsSettings)
                },
                LabDestination(title: "App Icon", systemImage: "app.badge.fill", color: .indigo) {
                    routes.push(.appIconSelection)
                },
                LabDestination(title: "Developer Info", systemImage: "person.circle.fill", color: .purple) {
                    routes.push(.developerInfo)
                },
                LabDestination(title: "Feedback", systemImage: "envelope.fill", color: .blue) {
                    routes.push(.feedback)
                },
            ])
        } header: {
            Text(verbatim: "Open a Screen")
        }
    }
}

// MARK: - Rows
private extension HatGameLabSections {
    /// Closes the lab, then goes there, so the screen isn't hidden behind it.
    func go(
        _ title: String,
        _ glyph: String,
        _ color: Color,
        _ route: @escaping @MainActor () -> Void
    ) -> some View {
        Button { closeTestingLab(then: route) } label: {
            LabRow(verbatim: title, systemImage: glyph, color: color)
        }
    }

    func toggle(_ title: String, _ isOn: Binding<Bool>, _ glyph: String, _ color: Color) -> some View {
        Toggle(isOn: isOn) {
            LabRow(verbatim: title, systemImage: glyph, color: color)
        }
    }

    func status(_ title: String, _ value: String, _ glyph: String, _ color: Color) -> some View {
        LabeledContent {
            Text(verbatim: value)
        } label: {
            LabRow(verbatim: title, systemImage: glyph, color: color)
        }
    }
}
#endif
