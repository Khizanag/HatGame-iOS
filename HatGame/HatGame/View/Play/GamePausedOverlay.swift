//
//  GamePausedOverlay.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import DesignBook
import SwiftUI

/// Full-screen blur that appears while the game timer is paused.
/// Honors Reduce Transparency by swapping the material for an opaque background.
struct GamePausedOverlay: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onResume: () -> Void

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: DesignBook.Spacing.xl) {
                Image(systemName: "pause.circle.fill")
                    .font(DesignBook.IconFont.emoji)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)

                Text(localized("game.paused.title"))
                    .font(DesignBook.Font.largeTitle)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                PrimaryButton(title: localized("common.buttons.continue"), icon: "play.fill") {
                    onResume()
                }
                .frame(width: DesignBook.Size.pauseButtonWidth)
            }
        }
    }
}

// MARK: - Subviews
private extension GamePausedOverlay {
    @ViewBuilder
    var backdrop: some View {
        if reduceTransparency {
            Rectangle()
                .fill(DesignBook.Color.Background.primary.opacity(0.95))
                .ignoresSafeArea()
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }
}
