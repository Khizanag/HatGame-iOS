//
//  FlowNavigationView.swift
//  Navigation Package
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import SwiftUI

/// The app's navigation root: owns a `Navigator`, routes `AnyPage` pushes
/// through one `navigationDestination`, and presents flows as covers.
/// Named to stay clear of SwiftUI's deprecated `NavigationView`.
public struct FlowNavigationView<RootContent: View>: View {
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
                // The one place the app's root navigationDestination lives.
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

    /// A flow rises from the bottom edge as the system presents a cover,
    /// never zoomed out of the button that opened it.
    private func coverContent(for page: AnyPage) -> some View {
        page.view()
            .environment(navigator)
            .environment(\.navZoomNamespace, zoomNamespace)
    }
}

// MARK: - Cross-platform cover presentation
private extension View {
    /// Presents `item` as a full-screen cover on iOS (the default for deliberate
    /// flows) and as a large page-sized sheet on macOS, which has no full-screen
    /// cover. The sheet sits below the title bar, so the window keeps its close
    /// and quit controls.
    @ViewBuilder
    func presentedCover<Item: Identifiable, Cover: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Cover
    ) -> some View {
        #if os(macOS)
        sheet(item: item) { value in
            content(value)
                .presentationSizing(.page)
        }
        #else
        fullScreenCover(item: item) { item in
            content(item).interactiveDismissDisabled()
        }
        #endif
    }
}
