//
//  FeedbackServiceTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import HatGame
import Networking
import Testing

@MainActor
@Suite("Feedback service")
struct FeedbackServiceTests {
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "FeedbackServiceTests-\(UUID().uuidString)"))
        defaults.set("device-123", forKey: "HatGame.deviceId")
    }

    @Test("A successful submission sends the trimmed message with diagnostics")
    func submitsTrimmedMessage() async {
        var sent: [Feedback] = []
        let service = FeedbackService(submitter: { sent.append($0) }, defaults: defaults)

        await service.submit(category: .idea, message: "  More rounds please \n")

        #expect(service.state == .submitted)
        #expect(sent.count == 1)
        #expect(sent.first?.category == "idea")
        #expect(sent.first?.message == "More rounds please")
        #expect(sent.first?.deviceId == "device-123")
        #expect(sent.first?.deviceModel?.isEmpty == false)
    }

    @Test("A blank message is not sent")
    func blankMessageIsIgnored() async {
        var sendCount = 0
        let service = FeedbackService(submitter: { _ in sendCount += 1 }, defaults: defaults)

        await service.submit(category: .bug, message: "   \n ")

        #expect(sendCount == 0)
        #expect(service.state == .editing)
    }

    @Test("A failure shows a localized message and can be retried")
    func failureIsLocalizedAndRetryable() async {
        let service = FeedbackService(
            submitter: { _ in throw NetworkingError.timeout },
            defaults: defaults
        )

        await service.submit(category: .other, message: "Hello")

        let message = service.errorMessage
        #expect(message == NetworkErrorMessage.message(for: NetworkingError.timeout))
        #expect(message?.isEmpty == false)

        service.resetAfterFailure()
        #expect(service.state == .editing)
        service.resetAfterFailure()
        #expect(service.state == .editing)
    }

    @Test("Every category has a title and an icon")
    func categoriesArePresentable() {
        for category in FeedbackCategory.allCases {
            #expect(!category.title.isEmpty)
            #expect(category.title != "feedback.category.\(category.rawValue)")
            #expect(!category.icon.isEmpty)
            #expect(category.id == category.rawValue)
        }
    }
}

@MainActor
@Suite("Game round")
struct GameRoundTests {
    @Test("Rounds advance in order and stop after the third")
    func nextRound() {
        #expect(GameRound.first.next == .second)
        #expect(GameRound.second.next == .third)
        #expect(GameRound.third.next == nil)
    }

    @Test("Each round has its own localized title, description, and symbol", arguments: GameRound.allCases)
    func presentation(round: GameRound) {
        #expect(round.title.contains("\(round.rawValue)"))
        #expect(!round.description.isEmpty)
        #expect(!round.description.hasPrefix("gameRound."))
        #expect(!round.symbol.isEmpty)
    }

    @Test("Round descriptions are distinct")
    func distinctDescriptions() {
        #expect(Set(GameRound.allCases.map(\.description)).count == GameRound.allCases.count)
        #expect(Set(GameRound.allCases.map(\.symbol)).count == GameRound.allCases.count)
    }
}
