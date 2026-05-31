//
//  ZoomTransition.swift
//  Navigation Package
//
//  Created by Giga Khizanishvili on 31.05.26.
//

import SwiftUI

/// The shared zoom-transition namespace owned by `NavigationView`, exposed so
/// source views (buttons/rows) can mark themselves as the zoom source for the
/// destination they present.
private struct NavZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

// MARK: - Environment access
public extension EnvironmentValues {
    var navZoomNamespace: Namespace.ID? {
        get { self[NavZoomNamespaceKey.self] }
        set { self[NavZoomNamespaceKey.self] = newValue }
    }
}

// MARK: - Zoom source modifier
public extension View {
    /// Marks this view as the zoom source for the navigation destination/cover
    /// whose page `id` matches. A no-op when no zoom namespace is available, so
    /// it is always safe to apply.
    @ViewBuilder
    func navigationZoomSource(id: String, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Applies the matching zoom transition for a pushed destination (iOS 18+).
    /// A no-op when no namespace is available, so it is always safe to apply.
    @ViewBuilder
    func navigationZoomDestination(id: String, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
