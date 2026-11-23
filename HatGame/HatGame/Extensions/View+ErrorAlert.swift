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
    /// `NetworkErrorMessage`, so it is always in the in-app language. With
    /// `retry`, the alert offers Try Again (constitution article 22).
    func errorAlert(
        _ error: Binding<(any Error)?>,
        title: String,
        transport: NetworkErrorMessage.Transport = .online,
        retry: (() -> Void)? = nil
    ) -> some View {
        errorAlert(
            title: title,
            message: error.wrappedValue.map { NetworkErrorMessage.message(for: $0, transport: transport) },
            onDismiss: { error.wrappedValue = nil },
            retry: retry
        )
    }

    /// Presents an alert titled `title` while `message` is non-nil;
    /// `onDismiss` runs once when the alert closes and must clear the source
    /// of `message`. With `retry`, Try Again runs it after the alert closes.
    func errorAlert(
        title: String,
        message: String?,
        onDismiss: @escaping () -> Void,
        retry: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(title: title, message: message, onDismiss: onDismiss, retry: retry))
    }
}

// MARK: - Modifier
private struct ErrorAlertModifier: ViewModifier {
    let title: String
    let message: String?
    let onDismiss: () -> Void
    let retry: (() -> Void)?

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
                if let retry {
                    Button(localized("common.tryAgain")) {
                        onDismiss()
                        retry()
                    }
                    Button(localized("common.buttons.cancel"), role: .cancel) { }
                } else {
                    Button(localized("common.buttons.close"), role: .cancel) { }
                }
            } message: {
                Text(message ?? "")
            }
            .haptic(.error, trigger: message != nil) { _, isFailing in isFailing }
    }
}
