//
//  NumberBadge.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 26.11.25.
//

import DesignBook
import SwiftUI

/// A row's place or a count beside a heading, in a disc: the one way the app
/// draws a small number (constitution article 30). Scales with the text
/// beside it, and its digits never shift (article 9).
struct NumberBadge: View {
    let number: Int

    @ScaledMetric(relativeTo: .subheadline) private var size = DesignBook.Size.badgeSize

    var body: some View {
        Text(verbatim: "\(number)")
            .font(DesignBook.Font.subheadline)
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(minWidth: size, minHeight: size)
            .padding(.horizontal, number > 9 ? DesignBook.Spacing.xs : 0)
            .background(DesignBook.Color.Background.secondary, in: .capsule)
    }
}

// MARK: - Preview
#Preview {
    HStack(spacing: DesignBook.Spacing.lg) {
        NumberBadge(number: 1)
        NumberBadge(number: 12)
    }
    .padding()
}
