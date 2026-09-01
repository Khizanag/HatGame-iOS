//
//  OnlinePlayer.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Foundation

public struct OnlinePlayer: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let deviceId: String
    public var name: String
    public var teamId: String?
    public var isReady: Bool
    public var hasSubmittedWords: Bool
    public var isConnected: Bool
    public let joinedAt: Date

    public init(
        id: String = UUID().uuidString,
        deviceId: String,
        name: String,
        teamId: String? = nil,
        isReady: Bool = false,
        hasSubmittedWords: Bool = false,
        isConnected: Bool = true,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.deviceId = deviceId
        self.name = name
        self.teamId = teamId
        self.isReady = isReady
        self.hasSubmittedWords = hasSubmittedWords
        self.isConnected = isConnected
        self.joinedAt = joinedAt
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: OnlinePlayer, rhs: OnlinePlayer) -> Bool {
        lhs.id == rhs.id
    }
}
