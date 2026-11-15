//
//  RoomLimitsTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("RoomLimits")
struct RoomLimitsTests {
    @Test("Text within the limit is unchanged")
    func shortTextUnchanged() {
        #expect(RoomLimits.name("Nino") == "Nino")
        #expect(RoomLimits.word("ბაყაყი") == "ბაყაყი")
    }

    @Test("Long text is cut to the limit in UTF-16 units without splitting a character")
    func longTextClamped() {
        let emoji = String(repeating: "😀", count: 60)

        let clamped = RoomLimits.name(emoji)

        #expect(clamped.utf16.count == 100)
        #expect(clamped == String(repeating: "😀", count: 50))
        #expect(RoomLimits.clamp("ab😀", to: 3) == "ab")
    }

    @Test("Model initializers clamp what they will write")
    func modelsClamp() {
        let long = String(repeating: "x", count: 500)

        #expect(OnlinePlayer(deviceId: "d", name: long).name.count == RoomLimits.maxNameLength)
        #expect(OnlineTeam(name: long, colorHex: "#000").name.count == RoomLimits.maxNameLength)
        #expect(OnlineWord(text: long, addedByPlayerId: "p").text.count == RoomLimits.maxWordLength)
        #expect(RoomLimits.feedback(String(repeating: "m", count: 6000)).count == RoomLimits.maxFeedbackLength)
    }
}
