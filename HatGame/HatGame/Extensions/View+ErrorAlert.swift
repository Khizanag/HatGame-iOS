//
//  View+ErrorAlert.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

// MARK: - Error alert
extension View {
    /// Presents a localized "Error" alert while `error` is non-nil and clears
    /// it when the alert is dismissed. The message is the error's
    /// `errorDescription` when it is a `LocalizedError`, otherwise its
    /// `localizedDescription`.
    func errorAlert(_ error: Binding<(any Error)?>) -> some View {
        errorAlert(
            message: error.wrappedValue.map(Self.message(for:)),
            onDismiss: { error.wrappedValue = nil }
        )
    }

    /// Presents a localized "Error" alert while `message` is non-nil;
    /// `onDismiss` runs once when the alert closes and must clear the source
    /// of `message`.
    func errorAlert(message: String?, onDismiss: @escaping () -> Void) -> some View {
        modifier(ErrorAlertModifier(message: message, onDismiss: onDismiss))
    }

    private static func message(for error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

// MARK: - Modifier
private struct ErrorAlertModifier: ViewModifier {
    let message: String?
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                localized("common.error"),
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
