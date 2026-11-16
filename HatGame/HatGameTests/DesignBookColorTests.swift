//
//  DesignBookColorTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI
import Testing

@Suite("DesignBook colors")
struct DesignBookColorTests {
    @Test
    func opaqueDropsTranslucency() {
        let translucent = Color(red: 0.2, green: 0.4, blue: 0.9, opacity: 0.3)

        let resolved = DesignBook.Color.opaque(translucent).resolve(in: EnvironmentValues())

        #expect(resolved.opacity == 1)
        #expect(abs(resolved.red - 0.2) < 0.001)
        #expect(abs(resolved.green - 0.4) < 0.001)
        #expect(abs(resolved.blue - 0.9) < 0.001)
    }

    @Test
    func opaqueKeepsAnOpaqueColor() {
        let resolved = DesignBook.Color.opaque(.red).resolve(in: EnvironmentValues())

        #expect(resolved == Color.red.resolve(in: EnvironmentValues()))
    }

    @Test
    func onAccentPicksBlackOnLightAndWhiteOnDark() {
        #expect(DesignBook.Color.onAccent(for: .yellow) == .black)
        #expect(DesignBook.Color.onAccent(for: Color(red: 0.1, green: 0.1, blue: 0.3)) == .white)
    }
}
