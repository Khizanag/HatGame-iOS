//
//  GameProgressFooter.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import DesignBook
import SwiftUI

/// Slim "X of Y words" progress bar tinted with the active team color.
struct GameProgressFooter: View {
    let passed: Int
    let total: Int
    let tint: Color

    private var safeTotal: Int { max(total, 1) }

    var body: some View {
        VStack(spacing: DesignBook.Spacing.xs) {
            HStack {
                Text(localized("game.progress.title"))
                    .font(DesignBook.Font.smallCaption)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                Spacer()
                Text(verbatim: "\(passed)/\(total)")
                    .font(DesignBook.Font.captionBold)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: Double(passed), total: Double(safeTotal))
                .tint(tint)
        }
        .padding(.bottom, DesignBook.Spacing.sm)
    }
}
