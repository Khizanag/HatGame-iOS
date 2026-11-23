//
//  HeroGlow.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The soft, blurred halo behind a hero's disc. Brand gradient by default;
/// a celebration or a team passes its own fill.
struct HeroGlow<Fill: ShapeStyle>: View {
    let glow: DesignBook.Size.Glow
    let fill: Fill
    let opacity: Double

    init(
        _ glow: DesignBook.Size.Glow,
        fill: Fill,
        opacity: Double = DesignBook.Opacity.semiTransparent
    ) {
        self.glow = glow
        self.fill = fill
        self.opacity = opacity
    }

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: glow.diameter, height: glow.diameter)
            .blur(radius: glow.blur)
            .opacity(opacity)
    }
}

// MARK: - Brand glow
extension HeroGlow where Fill == LinearGradient {
    init(_ glow: DesignBook.Size.Glow, opacity: Double = DesignBook.Opacity.semiTransparent) {
        self.init(glow, fill: DesignBook.Gradient.primary, opacity: opacity)
    }
}
