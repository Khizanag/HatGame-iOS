//
//  AnyPage.swift
//  Navigation Package
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import SwiftUI

/// Type-erased page for storage in Navigator
public struct AnyPage: Hashable, Identifiable, Sendable {
    public let id: String
    private let viewBuilder: @MainActor @Sendable () -> AnyView

    public init(id: String, viewBuilder: @escaping @MainActor @Sendable () -> AnyView) {
        self.id = id
        self.viewBuilder = viewBuilder
    }

    @MainActor @ViewBuilder
    public func view() -> some View {
        viewBuilder()
    }

    public static func == (lhs: AnyPage, rhs: AnyPage) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
