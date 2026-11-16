//
//  View+KeyboardDismiss.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

// MARK: - Interactive keyboard dismissal
extension View {
    /// Lets a drag on a form's scroll view pull the keyboard down. A no-op on
    /// visionOS, which has no scroll-driven keyboard dismissal.
    @ViewBuilder
    func dismissesKeyboardInteractively() -> some View {
        #if os(visionOS)
        self
        #else
        scrollDismissesKeyboard(.interactively)
        #endif
    }
}
