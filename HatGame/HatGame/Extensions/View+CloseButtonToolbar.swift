//
//  View+CloseButtonToolbar.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Navigation
import SwiftUI

// MARK: - Close item
/// The standard close button of a modal: leading edge, the system xmark,
/// Escape on a keyboard (HIG toolbars.md, sheets.md: Cancel/Close leads,
/// Done/confirm trails).
struct CloseToolbarItem: ToolbarContent {
    /// Overrides the system "Close" label when the button does more than
    /// dismiss, such as leaving a room.
    var accessibilityLabel: String?
    var accessibilityIdentifier = "common.close"
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            // The system "Close" label ignores the in-app language, so always
            // supply a localized one.
            closeButton
                .accessibilityLabel(Text(accessibilityLabel ?? localized("common.buttons.close")))
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    private var closeButton: some View {
        Button(role: .close, action: action)
            .keyboardShortcut(.cancelAction)
    }
}

// MARK: - Confirm item
/// The confirming action of a sheet form (Done, Create, Save): trailing
/// edge, on its own, disabled until the form is valid.
struct ConfirmToolbarItem: ToolbarContent {
    let title: String
    var canConfirm = true
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(title, role: .confirm, action: action)
                .disabled(!canConfirm)
        }
    }
}

// MARK: - Automatic close button
/// Shows a close button only when this view is the root of a modal flow
/// (the navigator's path is empty). Pushed screens keep the native back
/// button so iOS can supply the previous screen's title and chevron.
private struct NavigationButtonToolbarModifier: ViewModifier {
    @Environment(Navigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .toolbar {
                if navigator.navigationPath.isEmpty {
                    CloseToolbarItem { dismiss() }
                }
            }
    }
}

// MARK: - Navigation toolbar
extension View {
    func navigationButtonToolbar() -> some View {
        modifier(NavigationButtonToolbarModifier())
    }
}
