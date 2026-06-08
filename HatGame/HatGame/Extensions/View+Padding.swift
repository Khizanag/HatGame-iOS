//
//  View+Padding.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.25.
//

import DesignBook
import SwiftUI

extension View {
    /// Standard horizontal gutters plus a readable max-content-width cap that
    /// centers the column on wide windows (macOS / large iPad). A no-op on
    /// phone-width windows, where content is already narrower than the cap —
    /// so iPhone layout (and snapshot baselines) are unchanged.
    func paddingHorizontalDefault() -> some View {
        padding(.horizontal, DesignBook.Spacing.md)
            .frame(maxWidth: DesignBook.Size.maxContentWidth)
            .frame(maxWidth: .infinity)
    }
}
