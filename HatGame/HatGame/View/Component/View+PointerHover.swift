//
//  View+PointerHover.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

// MARK: - Pointer hover
extension View {
    /// Pointer and gaze feedback for custom and `.plain` buttons and tappable
    /// cards, which get none from the system (HIG pointing-devices.md). A
    /// no-op on macOS, where plain buttons have no hover highlight.
    @ViewBuilder
    func pointerHoverEffect() -> some View {
        #if os(macOS)
        self
        #else
        hoverEffect(.highlight)
        #endif
    }
}
