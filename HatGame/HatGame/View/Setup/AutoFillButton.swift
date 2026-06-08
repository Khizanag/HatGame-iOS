//
//  AutoFillButton.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 09.06.26.
//

import DesignBook
import SwiftUI

/// Word-input call-to-action that fills the remaining words automatically.
struct AutoFillButton: View {
    let isAutoFilling: Bool
    let isDisabled: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: isAutoFilling ? "sparkles" : "wand.and.stars")
                    .font(DesignBook.Font.body)
                    .fontWeight(.semibold)
                    .symbolEffect(.pulse, options: .repeating, isActive: isAutoFilling)
                Text(isAutoFilling ? "wordInput.autoFill.thinking" : "wordInput.autoFill")
                    .font(DesignBook.Font.body)
                    .fontWeight(.medium)
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        DesignBook.Color.Text.accent,
                        DesignBook.Color.Text.accent.opacity(0.8),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.vertical, DesignBook.Spacing.md)
            .padding(.horizontal, DesignBook.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(background)
            .shadow(color: DesignBook.Color.Text.accent.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? DesignBook.Opacity.disabled : DesignBook.Opacity.enabled)
    }
}

// MARK: - Background
private extension AutoFillButton {
    var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                .fill(
                    reduceTransparency
                        ? AnyShapeStyle(DesignBook.Color.Background.secondary)
                        : AnyShapeStyle(.ultraThinMaterial)
                )

            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignBook.Color.Text.accent.opacity(0.15),
                            DesignBook.Color.Text.accent.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignBook.Color.Text.accent.opacity(0.3),
                            DesignBook.Color.Text.accent.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }
}
