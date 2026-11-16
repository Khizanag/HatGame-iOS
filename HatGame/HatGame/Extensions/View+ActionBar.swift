//
//  View+ActionBar.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

// MARK: - Action bar
extension View {
    /// Places a screen's actions below its scrolling content.
    ///
    /// - iOS: pinned to the bottom edge with `safeAreaBar(edge: .bottom)`.
    ///   Scroll views under the bar run beneath it, and the soft scroll edge
    ///   effect fades the content as it passes under the buttons instead of an
    ///   opaque fill, so backdrops stay visible (HIG layout.md: differentiate
    ///   controls from content with a scroll edge effect).
    /// - macOS: inline at the end of the content, scrolling with it. People
    ///   often move a window's bottom edge off screen, so controls don't pin
    ///   there (HIG layout.md, macOS).
    /// - visionOS: pinned like iOS; the platform has no scroll edge effect,
    ///   and the window's glass already separates the controls.
    ///
    /// Apply it to the scroll view (or a container of it). `content` brings
    /// its own padding. Keep it to at most two buttons: the primary one full
    /// width, an optional secondary above it.
    @ViewBuilder
    func actionBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(macOS)
        modifier(InlineActionBar(bar: content()))
        #else
        safeAreaBar(edge: .bottom, content: content)
            .softBottomScrollEdge()
        #endif
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

#if os(macOS)
// MARK: - Inline action bar
/// Reserves room for the bar below the scroll content, then draws the bar at
/// the content's end so it moves with the content: right under it when the
/// content is short, out of view until people scroll to the end when it is
/// long.
private struct InlineActionBar<Bar: View>: ViewModifier {
    let bar: Bar

    @State private var barHeight: CGFloat = 0
    @State private var contentEnd: CGFloat?

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, barHeight)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // In the view's own frame, which starts below the toolbar
                // inset that the scroll content runs under.
                geometry.contentSize.height - geometry.contentOffset.y - geometry.contentInsets.top
            } action: { _, end in
                contentEnd = end
            }
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    bar
                        .frame(width: proxy.size.width)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 }
                        .offset(y: barOffset(in: proxy.size.height))
                }
                .clipped()
            }
    }

    private func barOffset(in height: CGFloat) -> CGFloat {
        let pinned = height - barHeight
        guard let contentEnd else { return pinned }
        return min(contentEnd, height)
    }
}
#endif
