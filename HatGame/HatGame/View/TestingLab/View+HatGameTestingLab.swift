#if DEBUG
import DesignBook
import Navigation
import SwiftUI
import TestingLab

extension View {
    /// Hosts the Testing Lab here. Home hosts it, and so does each flow's
    /// root, because a sheet can't open over a full-screen flow from below
    /// it: whichever host is on top shows the lab. Every host reads the app's
    /// root navigator, so the notes and shortcuts reach every screen.
    ///
    /// Opens on a shake, from Settings ▸ Developer Info, with ⌥⌘T on a Mac, or at
    /// launch with `-openTestingLab YES`.
    ///
    /// - Parameter isRoot: Home's host, which stands aside while a flow
    ///   covers it, so the flow's own host is the one that opens.
    func hatGameTestingLab(isRoot: Bool = false) -> some View {
        modifier(HatGameTestingLabModifier(isRoot: isRoot))
    }
}

// MARK: - Modifier
private struct HatGameTestingLabModifier: ViewModifier {
    @Environment(Navigator.self) private var navigator

    let isRoot: Bool

    func body(content: Content) -> some View {
        content
            .testingLab(
                notes: HatGameBuildNotes(routes: LabRoutes(navigator: navigator)).current,
                accent: DesignBook.Color.Text.accent,
                isEnabled: !isRoot || navigator.presentedPage == nil
            ) {
                HatGameLabSections()
            }
    }
}
#endif
