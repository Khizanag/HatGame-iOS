//
//  PlayerStepIndicator.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// One capsule per player: done, current (outlined), and upcoming.
struct PlayerStepIndicator: View {
    let playerCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: DesignBook.Spacing.xs) {
            ForEach(0..<playerCount, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(height: 6)
                    .overlay {
                        if index == currentIndex {
                            Capsule().stroke(DesignBook.Color.Text.accent, lineWidth: 2)
                        }
                    }
            }
        }
    }

    private func color(for index: Int) -> Color {
        if index < currentIndex {
            DesignBook.Color.Status.success
        } else if index == currentIndex {
            DesignBook.Color.Text.accent
        } else {
            DesignBook.Color.Background.secondary
        }
    }
}
