//
//  SettingsIconTile.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 08.06.26.
//

import DesignBook
import SwiftUI

/// The colored rounded-square icon at the leading edge of a settings row.
/// Brand color is expressed here in the content layer, iOS-Settings style.
struct SettingsIconTile: View {
    let systemImage: String
    var tint: Color = DesignBook.Color.Text.accent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignBook.Size.smallCardCornerRadius)
                .fill(tint.opacity(0.15))
                .frame(width: 32, height: 32)

            Image(systemName: systemImage)
                .font(DesignBook.Font.body)
                .foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }
}
