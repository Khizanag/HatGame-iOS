//
//  Navigator.swift
//  Navigation Package
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Combine
import Observation
import SwiftUI

@MainActor
@Observable
public final class Navigator {
    public var navigationPath: [AnyPage] = []
    public var presentedPage: AnyPage?
    /// The sheet over the current flow, presented by the flow's root so a
    /// screen never presents one itself.
    public var presentedSheet: AnyPage?

    private var pleaseDismissViewSubject = PassthroughSubject<Void, Never>()

    public var pleaseDismissViewPublisher: AnyPublisher<Void, Never> {
        pleaseDismissViewSubject.eraseToAnyPublisher()
    }

    public init() {}

    // MARK: - Navigation Methods
    public func push<Content: View>(_ page: Page<Content>) {
        navigationPath.append(page.eraseToAnyPage())
    }

    public func present<Content: View>(_ page: Page<Content>) {
        presentedPage = page.eraseToAnyPage()
    }

    public func presentSheet<Content: View>(_ page: Page<Content>) {
        presentedSheet = page.eraseToAnyPage()
    }

    public func dismissSheet() {
        presentedSheet = nil
    }

    public func dismiss() {
        pleaseDismissViewSubject.send()
    }

    public func dismissToRoot() {
        navigationPath = []
    }

    public func popToRoot() {
        dismissToRoot()
    }

    public func replace<Content: View>(with page: Page<Content>) {
        // Replace current page by removing last and adding new
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
        push(page)
    }
}
