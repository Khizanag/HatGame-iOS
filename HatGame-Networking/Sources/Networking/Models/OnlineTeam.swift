//
//  OnlineTeam.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Foundation

public struct OnlineTeam: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var colorHex: String
    public var playerIds: [String]

    public init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String,
        playerIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.playerIds = playerIds
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: OnlineTeam, rhs: OnlineTeam) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Codable
    /// `playerIds` is omitted from the stored snapshot when empty
    /// (Firebase strips empty arrays). Custom decoder defaults to [].
    private enum CodingKeys: String, CodingKey {
        case id, name, colorHex, playerIds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.colorHex = try container.decode(String.self, forKey: .colorHex)
        self.playerIds = (try? container.decode([String].self, forKey: .playerIds)) ?? []
    }
}
