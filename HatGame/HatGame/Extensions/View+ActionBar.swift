//
//  View+ActionBar.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

// MARK: - Action bar
extension View {
    /// Pins a screen's actions to the bottom edge, above its scrolling content.
    ///
    /// Built on `safeAreaBar(edge: .bottom)`: scroll views under the bar run
    /// beneath it, and the system scroll edge effect fades the content as it
    /// passes under the buttons instead of an opaque fill, so backdrops stay
    /// visible (HIG layout.md: differentiate controls from content with a
    /// scroll edge effect).
    ///
    /// - iOS: soft scroll edge effect.
    /// - macOS: the bar stays pinned at the window's bottom with the system's
    ///   default (hard) edge effect, which suits a desktop window.
    /// - visionOS: pinned the same way; the platform has no scroll edge
    ///   effect, and the window's glass already separates the controls.
    ///
    /// Apply it to the scroll view (or a container of it). `content` brings
    /// its own padding. Keep it to at most two buttons: the primary one full
    /// width, an optional secondary above it.
    func actionBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        safeAreaBar(edge: .bottom, content: content)
            .softBottomScrollEdge()
    }
}

// MARK: - Scroll edge
private extension View {
    @ViewBuilder
    func softBottomScrollEdge() -> some View {
        #if os(iOS)
        scrollEdgeEffectStyle(.soft, for: .bottom)
        #else
        self
        #endif
    }
}
