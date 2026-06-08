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
        .fullScreenCover(item: $navigator.presentedPage) { page in
            coverContent(for: page)
                // Presented flows are deliberate (game setup, nearby, online) —
                // they must be left via their own controls, never swiped away.
                .interactiveDismissDisabled()
        }
        .onReceive(navigator.pleaseDismissViewPublisher) {
            dismiss()
        }
    }

    @ViewBuilder
    private func coverContent(for page: AnyPage) -> some View {
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
    }
}
