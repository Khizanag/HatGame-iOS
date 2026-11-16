//
//  DesignBookContrastTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
@testable import HatGame
import SwiftUI
import Testing

@MainActor
@Suite("DesignBook contrast")
struct DesignBookContrastTests {
    private typealias Contrast = DesignBook.Contrast
    private typealias RGB = DesignBook.Contrast.RGB

    private static let lightBackground = RGB(red: 0.965, green: 0.969, blue: 1.0)
    private static let darkBackground = RGB(red: 0.05, green: 0.05, blue: 0.1)

    @Test
    func blackOnWhiteIsTheMaximumRatio() {
        #expect(abs(Contrast.ratio(between: .black, and: .white) - 21) < 0.001)
        #expect(abs(Contrast.ratio(between: .white, and: .black) - 21) < 0.001)
    }

    @Test
    func identicalColorsHaveNoContrast() {
        let color = RGB(red: 0.3, green: 0.6, blue: 1.0)

        #expect(Contrast.ratio(between: color, and: color) == 1)
    }

    @Test
    func luminanceMatchesTheWCAGReferenceValues() {
        #expect(Contrast.relativeLuminance(of: .black) == 0)
        #expect(abs(Contrast.relativeLuminance(of: .white) - 1) < 0.000_1)
        // sRGB #777777 is the classic 4.48:1-on-white gray.
        let gray = RGB(red: 119.0 / 255, green: 119.0 / 255, blue: 119.0 / 255)
        #expect(abs(Contrast.ratio(between: gray, and: .white) - 4.48) < 0.01)
    }

    @Test
    func adjustedLeavesAPassingColorUnchanged() {
        let navy = RGB(red: 0.1, green: 0.1, blue: 0.4)

        #expect(Contrast.adjusted(navy, against: Self.lightBackground) == navy)
    }

    @Test
    func adjustedDarkensOnALightBackgroundJustEnough() {
        let yellow = RGB(red: 0.9, green: 0.9, blue: 0.3)

        let adjusted = Contrast.adjusted(yellow, against: Self.lightBackground)
        let ratio = Contrast.ratio(between: adjusted, and: Self.lightBackground)

        #expect(ratio >= Contrast.minimumTextRatio)
        #expect(ratio < Contrast.minimumTextRatio + 0.05)
        #expect(Contrast.relativeLuminance(of: adjusted) < Contrast.relativeLuminance(of: yellow))
        // Mixing toward black keeps the hue: still more red/green than blue.
        #expect(adjusted.red > adjusted.blue)
    }

    @Test
    func adjustedLightensOnADarkBackground() {
        let purple = RGB(red: 0.35, green: 0.15, blue: 0.55)

        let adjusted = Contrast.adjusted(purple, against: Self.darkBackground)

        #expect(Contrast.ratio(between: adjusted, and: Self.darkBackground) >= Contrast.minimumTextRatio)
        #expect(Contrast.relativeLuminance(of: adjusted) > Contrast.relativeLuminance(of: purple))
    }

    @Test(arguments: TeamDefaultColorGenerator.defaultColors, [ColorScheme.light, .dark])
    func teamTextIsReadableOnTheBackground(teamColor: Color, scheme: ColorScheme) {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme

        let text = DesignBook.Color.teamText(for: teamColor).resolve(in: environment)
        let background = DesignBook.Color.Background.primary.resolve(in: environment)

        let ratio = Contrast.ratio(between: rgb(text), and: rgb(background))
        #expect(ratio >= Contrast.minimumTextRatio - 0.01, "\(scheme): \(ratio)")
    }

    @Test
    func teamTextKeepsAnAlreadyReadableColor() {
        let navy = Color(red: 0.1, green: 0.1, blue: 0.4)
        var environment = EnvironmentValues()
        environment.colorScheme = .light

        let text = DesignBook.Color.teamText(for: navy).resolve(in: environment)
        let original = navy.resolve(in: environment)

        #expect(abs(text.red - original.red) < 0.01)
        #expect(abs(text.green - original.green) < 0.01)
        #expect(abs(text.blue - original.blue) < 0.01)
    }
}

// MARK: - Helpers
private extension DesignBookContrastTests {
    func rgb(_ resolved: Color.Resolved) -> DesignBook.Contrast.RGB {
        DesignBook.Contrast.RGB(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
    }
}
