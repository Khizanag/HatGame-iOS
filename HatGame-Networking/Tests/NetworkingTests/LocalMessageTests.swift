//
//  LocalMessageTests.swift
//  NetworkingTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import Networking
import Testing

@Suite("Nearby protocol")
struct LocalMessageTests {
    @Test("Only the same protocol version is compatible")
    func versionCompatibility() {
        #expect(LocalProtocol.isCompatible(LocalProtocol.version))
        #expect(!LocalProtocol.isCompatible(LocalProtocol.version + 1))
        #expect(!LocalProtocol.isCompatible(nil))
    }

    @Test("A host advertising no version or another one is incompatible")
    func discoveryCompatibility() {
        let current = [LocalProtocol.discoveryKey: String(LocalProtocol.version)]

        #expect(LocalProtocol.isCompatible(discoveryInfo: current))
        #expect(!LocalProtocol.isCompatible(discoveryInfo: ["host": "Ann"]))
        #expect(!LocalProtocol.isCompatible(discoveryInfo: [LocalProtocol.discoveryKey: "2"]))
        #expect(!LocalProtocol.isCompatible(discoveryInfo: [LocalProtocol.discoveryKey: "x"]))
    }

    @Test("A hello carries the guest's protocol version")
    func helloRoundTrip() throws {
        let player = OnlinePlayer(id: "p", deviceId: "d", name: "Ann")
        let data = try JSONEncoder().encode(LocalMessage.helloFromGuest(player, protocolVersion: 7))

        let decoded = try JSONDecoder().decode(LocalMessage.self, from: data)

        guard case let .helloFromGuest(received, version) = decoded else {
            Issue.record("Expected a hello")
            return
        }
        #expect(received.id == "p")
        #expect(version == 7)
    }

    @Test("A room snapshot carries the host's clock")
    func snapshotCarriesHostTime() throws {
        let hostTime = Date(timeIntervalSinceReferenceDate: 800_000_123)
        let room = GameRoom(id: "local-1", hostId: "h")
        let data = try JSONEncoder().encode(LocalMessage.roomSnapshot(room, hostTime: hostTime))

        guard case let .roomSnapshot(decoded, time) = try JSONDecoder().decode(LocalMessage.self, from: data) else {
            Issue.record("Expected a snapshot")
            return
        }
        #expect(decoded.id == "local-1")
        #expect(time == hostTime)
    }

    @Test("Departure messages survive the wire")
    func departureMessagesRoundTrip() throws {
        for message in [LocalMessage.guestLeaving, .roomClosed] {
            let decoded = try JSONDecoder().decode(LocalMessage.self, from: JSONEncoder().encode(message))
            switch (message, decoded) {
            case (.guestLeaving, .guestLeaving), (.roomClosed, .roomClosed):
                break
            default:
                Issue.record("Expected \(message), got \(decoded)")
            }
        }
    }

    @Test("An unknown rejection reason decodes as refused")
    func unknownRejection() throws {
        let decoded = try JSONDecoder().decode(HelloRejection.self, from: Data(#""roomFull""#.utf8))

        #expect(decoded == .refused)
    }
}
