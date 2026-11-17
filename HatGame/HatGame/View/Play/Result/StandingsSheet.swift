//
//  StandingsSheet.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

/// The mid-game standings, presented as a view-only sheet over the game
/// loop: medium or large, with the standard Close button (and Escape) for
/// platforms without a swipe-down gesture.
struct StandingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ResultsView()
                .toolbar {
                    CloseToolbarItem { dismiss() }
                }
        }
        // The glass sheet shows through at medium height; at large the
        // system turns it opaque.
        .environment(\.showsScreenBackground, false)
        .presentationDetents([.medium, .large])
    }
}
