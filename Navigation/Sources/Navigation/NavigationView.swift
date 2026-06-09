//
//  NavigationView.swift
//  Navigation Package
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import SwiftUI

public struct NavigationView<RootContent: View>: View {
    @State private var navigator = Navigator()
    @Namespace private var zoomNamespace
    @ViewBuilder private let rootContent: () -> RootContent
    @Environment(\.dismiss) private var dismiss

    public init(@ViewBuilder rootContent: @escaping () -> RootContent) {
        self.rootContent = rootContent
    }

    public var body: some View {
        NavigationStack(path: $navigator.navigationPath) {
            rootContent()
                // This IS the navigation stack wrapper — the one place the
                // app's single navigationDestination is allowed to live.
                // swiftlint:disable:next no_navigation_destination
                .navigationDestination(for: AnyPage.self) { page in
                    page.view()
                }
        }
        .environment(navigator)
        .environment(\.navZoomNamespace, zoomNamespace)
        // Presented flows are deliberate (game setup, nearby, online). They are
        // full-screen covers on iOS (left only via their own controls) and
        // sheets on macOS, which has no full-screen cover.
        .presentedCover(item: $navigator.presentedPage) { page in
            coverContent(for: page)
        }
        .onReceive(navigator.pleaseDismissViewPublisher) {
            dismiss()
        }
    }

    @ViewBuilder
    private func coverContent(for page: AnyPage) -> some View {
        #if os(macOS)
        page.view()
            .environment(navigator)
            .environment(\.navZoomNamespace, zoomNamespace)
        #else
        if #available(iOS 18.0, *) {
            page.view()
                .environment(navigator)
                .environment(\.navZoomNamespace, zoomNamespace)
                .navigationTransition(.zoom(sourceID: page.id, in: zoomNamespace))
        } else {
            page.view()
                .environment(navigator)
                .environment(\.navZoomNamespace, zoomNamespace)
        }
        #endif
    }
}

// MARK: - Cross-platform cover presentation
private extension View {
    /// Presents `item` as a full-screen cover on iOS (the default for deliberate
    /// flows) and as a sheet on macOS, which has no full-screen cover.
    @ViewBuilder
    func presentedCover<Item: Identifiable, Cover: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Cover
    ) -> some View {
        #if os(macOS)
        sheet(item: item, content: content)
        #else
        fullScreenCover(item: item) { item in
            content(item).interactiveDismissDisabled()
        }
        #endif
    }
}
