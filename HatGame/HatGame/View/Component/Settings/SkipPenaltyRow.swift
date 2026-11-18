//
//  SkipPenaltyRow.swift
//  HatGame
//

import SwiftUI

/// How many points a skip costs: none to three, spelled "None" or "−1 point".
/// Shared by game setup, the defaults in Settings, and the room forms.
struct SkipPenaltyRow: View {
    @Binding var penalty: Int
    var range: ClosedRange<Int> = GameRules.skipPenaltyRange

    var body: some View {
        GameSettingsRow(
            icon: "minus.circle",
            title: localized("skipPenalty.title"),
            value: $penalty,
            range: range,
            step: 1,
            format: Self.label(for:)
        )
    }

    static func label(for penalty: Int) -> String {
        penalty == 0 ? localized("skipPenalty.none") : localized("skipPenalty.points \(penalty)")
    }

    /// The Skip button's title, with its cost when it has one: "Skip −1".
    static func skipTitle(penalty: Int) -> String {
        penalty == 0 ? localized("game.skip") : localized("game.skip.penalty \(penalty)")
    }

    static func skipAccessibilityLabel(penalty: Int) -> String {
        penalty == 0 ? localized("game.skip") : localized("game.skip.penalty.a11y \(penalty)")
    }
}
