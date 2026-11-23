//
//  FoldableCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

/// A card that folds open to show more. What it reveals is reading content,
/// so the card stays opaque; its header is the row that folds it.
struct FoldableCard<Content: View>: View {
    // MARK: - Properties
    @Binding var isExpanded: Bool
    let title: String
    let description: String?
    let icon: String?
    let titleFont: Font
    let descriptionFont: Font
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Init
    init(
        isExpanded: Binding<Bool>,
        title: String,
        description: String? = nil,
        icon: String? = nil,
        titleFont: Font = DesignBook.Font.title3,
        descriptionFont: Font = DesignBook.Font.body,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isExpanded = isExpanded
        self.title = title
        self.description = description
        self.icon = icon
        self.titleFont = titleFont
        self.descriptionFont = descriptionFont
        self.content = content
    }

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                headerButton

                if isExpanded {
                    content()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

// MARK: - Private
private extension FoldableCard {
    var headerButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                HStack {
                    HStack(spacing: DesignBook.Spacing.sm) {
                        if let icon {
                            Image(systemName: icon)
                                .font(titleFont)
                                .foregroundStyle(DesignBook.Color.Text.primary)
                        }

                        Text(title)
                            .font(titleFont)
                            .foregroundStyle(DesignBook.Color.Text.primary)
                    }

                    Spacer()

                    chevronIcon
                }

                if let description {
                    Text(description)
                        .font(descriptionFont)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: DesignBook.Size.touchTargetSize, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .pointerHoverEffect()
        .accessibilityValue(Text(localized(isExpanded ? "common.state.expanded" : "common.state.collapsed")))
    }

    var chevronIcon: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(DesignBook.Font.title3)
            .foregroundStyle(DesignBook.Color.Text.primary)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignBook.Spacing.lg) {
        FoldableCard(
            isExpanded: .constant(true),
            title: "How to Play"
        ) {
            Text(verbatim: "Content here")
        }

       FoldableCard(
           isExpanded: .constant(false),
           title: "Round 1",
           description: "No restrictions"
       ) {
           Text(verbatim: "Round content here")
       }
    }
    .padding()
    .background(DesignBook.Color.Background.primary)
}
