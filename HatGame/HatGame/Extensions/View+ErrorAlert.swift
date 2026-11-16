//
//  View+ErrorAlert.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

// MARK: - Error alert
extension View {
    /// Presents an alert while `error` is non-nil and clears it when the
    /// alert is dismissed. `title` names what failed ("Couldn't Join Room") —
    /// never just "Error" (HIG alerts.md). The message comes from
    /// `NetworkErrorMessage`, so it is always in the in-app language.
    func errorAlert(
        _ error: Binding<(any Error)?>,
        title: String,
        transport: NetworkErrorMessage.Transport = .online
    ) -> some View {
        errorAlert(
            title: title,
            message: error.wrappedValue.map { NetworkErrorMessage.message(for: $0, transport: transport) },
            onDismiss: { error.wrappedValue = nil }
        )
    }

    /// Presents an alert titled `title` while `message` is non-nil;
    /// `onDismiss` runs once when the alert closes and must clear the source
    /// of `message`.
    func errorAlert(title: String, message: String?, onDismiss: @escaping () -> Void) -> some View {
        modifier(ErrorAlertModifier(title: title, message: message, onDismiss: onDismiss))
    }
}

// MARK: - Modifier
private struct ErrorAlertModifier: ViewModifier {
    let title: String
    let message: String?
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                title,
                isPresented: Binding(
                    get: { message != nil },
                    set: { isPresented in
                        if !isPresented { onDismiss() }
                    }
                )
            ) {
                Button(localized("common.gotIt"), role: .cancel) { }
            } message: {
                Text(message ?? "")
            }
    }
}
