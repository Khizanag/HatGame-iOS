//
//  View+Haptic.swift
//  HatGame
//

import SwiftUI

// MARK: - Haptics
extension View {
    /// Plays `feedback` when `trigger` changes and `when` holds for its old and
    /// new values, on the view that owns that state (constitution article 23).
    /// Silent while the person has turned Haptics off.
    func haptic<Trigger: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: Trigger,
        when condition: @escaping (Trigger, Trigger) -> Bool = { _, _ in true }
    ) -> some View {
        modifier(HapticModifier(feedback: feedback, trigger: trigger, condition: condition))
    }
}

/// Reads the Haptics setting where it is observed, so turning it off takes
/// effect on the next change without a relaunch.
private struct HapticModifier<Trigger: Equatable>: ViewModifier {
    let feedback: SensoryFeedback
    let trigger: Trigger
    let condition: (Trigger, Trigger) -> Bool

    func body(content: Content) -> some View {
        let isEnabled = AppConfiguration.shared.isHapticsEnabled
        content.sensoryFeedback(trigger: trigger) { old, new in
            isEnabled && condition(old, new) ? feedback : nil
        }
    }
}
