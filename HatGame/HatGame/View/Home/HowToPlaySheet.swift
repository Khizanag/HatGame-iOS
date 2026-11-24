//
//  HowToPlaySheet.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The rules, opened from Home's toolbar: a view-only sheet, medium or
/// large, closed with the standard Close (and Escape).
struct HowToPlaySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                    ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                        InstructionRow(index: index + 1, icon: step.icon, text: localized(step.text))
                    }
                }
                .paddingHorizontalDefault()
                .padding(.vertical, DesignBook.Spacing.md)
            }
            .navigationTitle(localized("home.howToPlay.title"))
            .inlineNavigationTitle()
            .setDefaultBackground()
            .toolbar {
                CloseToolbarItem { dismiss() }
            }
        }
        .controlTint()
        // The glass sheet shows through at medium height; at large the
        // system turns it opaque.
        .environment(\.showsScreenBackground, false)
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("howToPlay.sheet")
    }
}

// MARK: - Steps
private extension HowToPlaySheet {
    static let steps: [(icon: String, text: String.LocalizationValue)] = [
        (icon: "person.2.fill", text: "home.instructions.createTeams"),
        (icon: "text.bubble.fill", text: "home.instructions.addWords"),
        (icon: "shuffle.circle.fill", text: "home.instructions.randomize"),
        (icon: "1.circle.fill", text: "home.instructions.round1"),
        (icon: "2.circle.fill", text: "home.instructions.round2"),
        (icon: "3.circle.fill", text: "home.instructions.round3"),
        (icon: "trophy.fill", text: "home.instructions.winner"),
    ]
}

// MARK: - Preview
#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        HowToPlaySheet()
    }
}
