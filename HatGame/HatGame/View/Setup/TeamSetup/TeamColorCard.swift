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

    private let appConfiguration = AppConfiguration.shared

    private var colorSectionState: String {
        localized(isExpanded ? "common.state.expanded" : "common.state.collapsed")
    }

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                colorCardHeader

                if isExpanded {
                    colorPicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
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
                Image(systemName: "paintpalette.fill")
                    .font(DesignBook.IconFont.medium)
                    .foregroundStyle(DesignBook.Color.Text.accent)

                Text(localized("teamForm.teamColor"))
                    .font(DesignBook.Font.subheadlineSemibold)
                    .foregroundStyle(DesignBook.Color.Text.secondary)

                Spacer()

                if !isExpanded {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(DesignBook.Color.Text.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(Text(colorSectionState))
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

                ColorPicker(
                    localized("teamForm.customColor"),
                    selection: Binding(
                        get: { color },
                        set: { selectColor($0) }
                    ),
                    supportsOpacity: true
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

    func selectColor(_ color: Color) {
        DesignBook.Haptics.selection()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            self.color = color
            isExpanded = false
        }
    }
}
