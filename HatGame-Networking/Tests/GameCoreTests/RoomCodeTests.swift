//
//  RoomCodeTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("RoomCode")
struct RoomCodeTests {
    @Test("Generated codes are valid and avoid look-alike characters")
    func generatedCodesAreValid() {
        for _ in 0..<200 {
            let code = RoomCode.random()

            #expect(RoomCode.isValid(code))
            #expect(!code.contains { "IO01".contains($0) })
        }
    }

    @Test(
        "Typed input keeps only code characters",
        arguments: [
            ("ab-c2 3", "ABC23"),
            ("io01xyz", "XYZ"),
            ("hjkmnpqrst", "HJKMNP"),
            ("ⅠⅡ😀", ""),
        ]
    )
    func sanitizesInput(input: String, expected: String) {
        #expect(RoomCode.sanitized(input) == expected)
    }

    @Test("Validity needs six alphabet characters")
    func validity() {
        #expect(RoomCode.isValid("ABC234"))
        #expect(!RoomCode.isValid("ABC23"))
        #expect(!RoomCode.isValid("ABC2340"))
        #expect(!RoomCode.isValid("abc234"))
        #expect(!RoomCode.isValid("ABCIO1"))
    }
}
