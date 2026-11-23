//
//  View+ControlTint.swift
//  HatGame
//

import DesignBook
import SwiftUI

// MARK: - Control colour
extension View {
    /// Tints everything below in the label colour, so menus, links, toolbar
    /// items, and plain glass buttons draw like the system's own. The accent
    /// is named only where the constitution allows it (article 6): the
    /// primary action, a toggle's on state, a selected checkmark. Set once on
    /// each flow's navigation stack (article 7).
    func controlTint() -> some View {
        tint(DesignBook.Color.Text.primary)
    }

    /// The accent, for the few controls that wear it: a screen's one primary
    /// action and a toggle's on state.
    func accentTint() -> some View {
        tint(DesignBook.Color.Text.accent)
    }
}
