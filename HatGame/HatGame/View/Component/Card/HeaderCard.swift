//
//  HeaderCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

struct HeaderCard<Content: View>: View {
    let title: String
    let description: String?
    @ViewBuilder let content: () -> Content

    init(title: String, description: String? = nil, @ViewBuilder content: @escaping () -> Content = { EmptyView() }) {
        self.title = title
        self.description = description
        self.content = content
    }

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
                Text(title)
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let description {
                    Text(description)
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                content()
            }
        }
        .padding(.top, DesignBook.Spacing.lg)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignBook.Spacing.lg) {
        HeaderCard(
            title: "Round timer",
            description: "Each team gets the same amount of time per turn. Choose how intense you want the round to be."
        )

        HeaderCard(title: "How many words?") {
            ProgressView(value: 0.5)
                .tint(DesignBook.Color.Text.accent)
        }
    }
    .setDefaultBackground()
}
