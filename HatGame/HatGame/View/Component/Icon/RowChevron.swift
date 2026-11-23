//
//  RowChevron.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The trailing mark of a row that does something when tapped: the system's
/// chevron, in one size, colour, and column, whatever the tap does
/// (constitution article 30).
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.forward")
            .font(DesignBook.Font.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(DesignBook.Color.Text.tertiary)
            .accessibilityHidden(true)
    }
}
