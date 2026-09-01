//
//  Page.swift
//  Navigation Package
//
//  Created by Giga Khizanishvili on 29.11.24.
//

import SwiftUI

public struct Page<Content: View>: Hashable, Identifiable, Sendable where Content: Sendable {
    public let id: String
    @ViewBuilder private let content: @MainActor @Sendable () -> Content

    public init(id: String, @ViewBuilder view: @escaping @MainActor @Sendable () -> Content) {
        self.id = id
        self.content = view
    }

    @MainActor @ViewBuilder
    public func view() -> Content {
        content()
    }

    // Hashable conformance
    public static func == (lhs: Page<Content>, rhs: Page<Content>) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Convert to type-erased version for storage
    @MainActor
    public func eraseToAnyPage() -> AnyPage {
        let viewBuilder = self.content
        return AnyPage(id: id, viewBuilder: { AnyView(viewBuilder()) })
    }
}
