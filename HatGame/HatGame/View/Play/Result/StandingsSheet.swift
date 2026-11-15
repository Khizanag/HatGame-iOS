//
//  StandingsSheet.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

/// The mid-game standings, presented as a sheet over the game loop. Its Done
/// button (and Escape) closes it on platforms without a swipe-down gesture.
struct StandingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ResultsView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localized("common.buttons.done")) {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("standings.done")
                    }
                }
        }
    }
}
