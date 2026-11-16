//
//  SettingsPickerRow.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 08.06.26.
//

import DesignBook
import SwiftUI

/// A settings row that picks one value from a short list: the colored icon
/// tile and title lead, the current value trails, and the row opens a menu
/// of the options with a checkmark on the selected one.
///
/// The whole row is one control at least 44 pt tall, named by its title with
/// the selection as its value, so a tap anywhere opens the menu and VoiceOver
/// and Voice Control see a single, named element (HIG menus.md, pickers.md).
/// macOS uses the native pop-up button instead, the standard picker there.
struct SettingsPickerRow<Selection: Hashable, Options: View>: View {
    let icon: String
    var tint: Color = DesignBook.Color.Text.accent
    let title: String
    /// The selection's display name, shown at the trailing edge.
    let value: String
    var valueSystemImage: String?
    @Binding var selection: Selection
    @ViewBuilder let options: () -> Options

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        #if os(macOS)
        Picker(selection: $selection, content: options) {
            HStack(spacing: DesignBook.Spacing.md) {
                SettingsIconTile(systemImage: icon, tint: tint)
                titleText
            }
        }
        .pickerStyle(.menu)
        #else
        Menu {
            Picker(title, selection: $selection, content: options)
                .pickerStyle(.inline)
        } label: {
            rowLabel
        }
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
        #endif
    }
}

// MARK: - Subviews
private extension SettingsPickerRow {
    var titleText: some View {
        Text(title)
            .font(DesignBook.Font.body)
            .foregroundStyle(DesignBook.Color.Text.primary)
    }

    /// Title and value on one line when both fit in full; otherwise the
    /// value moves under the title rather than truncating either.
    var rowLabel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignBook.Spacing.md) {
                SettingsIconTile(systemImage: icon, tint: tint)
                titleText
                    .fixedSize()
                Spacer(minLength: DesignBook.Spacing.sm)
                valueLabel
                    .fixedSize()
                chevrons
            }
            stackedLabel
        }
        .modifier(RowShape())
    }

    var stackedLabel: some View {
        HStack(spacing: DesignBook.Spacing.md) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    SettingsIconTile(systemImage: icon, tint: tint)
                    titleText
                    valueLabel
                }
            } else {
                SettingsIconTile(systemImage: icon, tint: tint)
                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    titleText
                    valueLabel
                }
            }
            Spacer(minLength: 0)
            chevrons
        }
    }

    var valueLabel: some View {
        HStack(spacing: DesignBook.Spacing.xs) {
            if let valueSystemImage {
                Image(systemName: valueSystemImage)
            }
            Text(value)
        }
        .font(DesignBook.Font.body)
        .foregroundStyle(DesignBook.Color.Text.secondary)
    }

    var chevrons: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(DesignBook.Font.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(DesignBook.Color.Text.tertiary)
    }
}

// MARK: - Row shape
/// Makes the full row, transparent gaps included, the hit target. With the
/// 32 pt tile and the list row insets, the row is taller than 44 pt.
private struct RowShape: ViewModifier {
    func body(content: Content) -> some View {
        content.contentShape(.rect)
    }
}
