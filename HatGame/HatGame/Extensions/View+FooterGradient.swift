//
//  View+FooterGradient.swift
//  HatGame
//
//  Created by Giga Khizanishvili
//

import DesignBook
import SwiftUI

extension View {
    /// Adds a soft scroll-edge fade above footer content. The gradient's frame
    /// is stretched down into the bottom safe area via a `GeometryReader` so
    /// the opaque bottom of the gradient reaches the home-indicator zone,
    /// regardless of whether the host is a cover root or a sheet (where
    /// `.ignoresSafeArea` on a `.background` child alone doesn't extend).
    /// Crucially, this never paints a solid opaque rectangle behind the
    /// footer — the gradient stays a gradient, so heroes (HomeView's brand
    /// backdrop) still show through the fade.
    func withFooterGradient() -> some View {
        self
            .background {
                GeometryReader { proxy in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: DesignBook.Color.Background.primary.opacity(0), location: 0.0),
                            .init(color: DesignBook.Color.Background.primary.opacity(0.85), location: 0.18),
                            .init(color: DesignBook.Color.Background.primary, location: 0.32),
                            .init(color: DesignBook.Color.Background.primary, location: 1.0),
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height + proxy.safeAreaInsets.bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
            }
    }
}
