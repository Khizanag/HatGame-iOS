//
//  InstructionRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

struct InstructionRow: View {
    let index: Int?
    let icon: String
    let text: String

    @ScaledMetric(relativeTo: .subheadline) private var iconDiscSize: CGFloat = 32

    init(index: Int? = nil, icon: String, text: String) {
        self.index = index
        self.icon = icon
        self.text = text
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignBook.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignBook.Color.Text.accent.opacity(0.14))
                    .frame(width: iconDiscSize, height: iconDiscSize)

                Image(systemName: icon)
                    .font(DesignBook.Font.captionBold)
                    .foregroundStyle(DesignBook.Color.Text.accent)
            }

            Text(text)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let index {
                Text(verbatim: "\(index)")
                    .font(DesignBook.Font.smallCaption)
                    .foregroundStyle(DesignBook.Color.Text.tertiary)
                    .monospacedDigit()
                    .padding(.horizontal, DesignBook.Spacing.sm)
                    .padding(.vertical, 2)
                    .background {
                        Capsule().fill(DesignBook.Color.Background.secondary)
                    }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        InstructionRow(index: 1, icon: "person.2.fill", text: "Create teams and add players")
        InstructionRow(icon: "trophy.fill", text: "Whoever scores the most wins")
    }
    .padding()
    .setDefaultBackground()
}
