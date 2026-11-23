//
//  TeamColorCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The collapsible team color card: a swatch summary that expands into
/// the palette plus a custom color picker.
struct TeamColorCard: View {
    @Binding var color: Color
    /// Colors other teams use; their swatches are disabled.
    let occupiedColors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var palettePicks = 0

    private let appConfiguration = AppConfiguration.shared

    private var colorSectionState: String {
        localized(isExpanded ? "common.state.expanded" : "common.state.collapsed")
    }

    /// The palette name of the current color, or "Custom Color" for a picked one.
    private var colorName: String {
        suggestedColorOptions.firstIndex { color.isApproximatelyEqual(to: $0) }
            .map(TeamColorName.name(forPaletteIndex:))
            ?? localized("teamForm.customColor")
    }

    var body: some View {
        // Folds open like `FoldableCard`, so it is glass the same way.
        VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
            colorCardHeader

            if isExpanded {
                colorPicker
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignBook.Spacing.md)
        .frame(maxWidth: .infinity)
        .glassCard()
        .haptic(.selection, trigger: palettePicks)
    }
}

// MARK: - Subviews
private extension TeamColorCard {
    var colorCardHeader: some View {
        Button {
            withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: DesignBook.Spacing.sm) {
                Label {
                    Text(localized("teamForm.teamColor"))
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                } icon: {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(DesignBook.Color.Text.accent)
                }
                .font(DesignBook.Font.subheadlineSemibold)

                Spacer()

                if !isExpanded {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            }
            // The whole row, not just its glyphs, toggles the card.
            .frame(minHeight: DesignBook.Size.touchTargetSize)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .pointerHoverEffect()
        .accessibilityValue(Text(localized("teamForm.color.a11y \(colorName) \(colorSectionState)")))
    }

    var colorPicker: some View {
        HStack {
            if appConfiguration.isRightHanded {
                Spacer()
            }

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: DesignBook.Size.colorSwatchSize), spacing: DesignBook.Spacing.md),
                ],
                spacing: DesignBook.Spacing.md
            ) {
                ForEach(suggestedColorOptions.indices, id: \.self) { index in
                    ColorSwatchButton(
                        color: suggestedColorOptions[index],
                        name: TeamColorName.name(forPaletteIndex: index),
                        isSelected: isColorSelected(suggestedColorOptions[index]),
                        isDisabled: isColorOccupiedByOtherTeam(suggestedColorOptions[index]),
                        onSelect: { selectColor(suggestedColorOptions[index]) }
                    )
                }

                // The picker writes its binding back when it appears, so its
                // setter only assigns — collapsing here would close the card
                // the moment it opened.
                ColorPicker(
                    localized("teamForm.customColor"),
                    selection: $color,
                    supportsOpacity: false
                )
                .labelsHidden()
                .frame(width: DesignBook.Size.colorSwatchSize, height: DesignBook.Size.colorSwatchSize)
                .padding(DesignBook.Spacing.sm)
                .background(DesignBook.Color.Background.secondary)
                .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
                .contentShape(Rectangle())
            }
        }
    }

    var suggestedColorOptions: [Color] {
        TeamDefaultColorGenerator.defaultColors
    }
}

// MARK: - Actions
private extension TeamColorCard {
    func isColorSelected(_ candidate: Color) -> Bool {
        color.isApproximatelyEqual(to: candidate)
    }

    func isColorOccupiedByOtherTeam(_ candidate: Color) -> Bool {
        occupiedColors.contains { candidate.isApproximatelyEqual(to: $0) }
    }

    /// A palette pick is final, so the card closes on it.
    func selectColor(_ color: Color) {
        palettePicks += 1
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            self.color = color
            isExpanded = false
        }
    }
}
