//
//  View+DynamicType.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import SwiftUI

// MARK: - Decorative hero sizing
extension View {
    /// Pins decorative hero art — a glyph drawn inside a fixed-size disc — to
    /// the default text size, so the glyph never outgrows its disc at large
    /// accessibility sizes. Text around the art keeps scaling.
    func decorativeHeroSizing() -> some View {
        dynamicTypeSize(.large)
    }
}
