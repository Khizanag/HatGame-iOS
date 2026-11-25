//
//  StatTile.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// A figure and what it counts, on an opaque card: the Rules page's facts,
/// a game's highlights. `detail` adds who or when under the caption.
struct StatTile: View {
    let value: String
    let caption: String
    var detail: String?
    var accent: Color?

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                Text(verbatim: value)
                    .font(DesignBook.Font.title1)
                    .monospacedDigit()
                    .foregroundStyle(accent.map(DesignBook.Color.teamText(for:)) ?? DesignBook.Color.Text.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(caption)
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(DesignBook.Font.footnote)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tile rows
/// Tiles two to a row; stacked at accessibility sizes, where half a row is
/// too narrow for the captions.
struct StatTileGrid<Item: Identifiable, Tile: View>: View {
    let items: [Item]
    @ViewBuilder let tile: (Item) -> Tile

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { start in
                layout {
                    ForEach(items[start ..< min(start + 2, items.count)]) { item in
                        tile(item)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DesignBook.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignBook.Spacing.md))
    }
}

// MARK: - Preview
#Preview {
    StatTile(value: "12", caption: "Best explainer", detail: "Ann · Alpha", accent: .blue)
        .padding()
        .setDefaultBackground()
}
