//
//  ColorSwatchButton.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// A selectable palette color in the team color picker.
struct ColorSwatchButton: View {
    let color: Color
    let name: String
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Circle()
                .fill(color)
                .frame(width: DesignBook.Size.colorSwatchSize, height: DesignBook.Size.colorSwatchSize)
                .overlay(overlay.decorativeHeroSizing())
                .opacity(isDisabled ? DesignBook.Opacity.disabled : DesignBook.Opacity.enabled)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .pointerHoverEffect()
        .disabled(isDisabled)
        .accessibilityLabel(Text(name))
        .accessibilityValue(isDisabled ? Text(localized("teamForm.color.swatch.taken")) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - ColorSwatchButton subviews
private extension ColorSwatchButton {
    @ViewBuilder
    var overlay: some View {
        if isSelected {
            Image(systemName: "checkmark")
                .font(DesignBook.Font.bodyBold)
                .foregroundStyle(DesignBook.Color.onAccent(for: color))
        } else if isDisabled {
            Image(systemName: "xmark")
                .font(DesignBook.Font.footnoteBold)
                .foregroundStyle(DesignBook.Color.onAccent(for: color))
                .opacity(DesignBook.Opacity.disabled)
        }
    }
}
