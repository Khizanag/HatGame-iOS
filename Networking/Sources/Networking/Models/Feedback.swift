//
//  Feedback.swift
//  Networking
//
//  Created by Giga Khizanishvili on 01.06.26.
//

import Foundation

/// A single piece of user feedback, persisted to Firebase under
/// `/feedback/<id>`. Carries the message plus lightweight, non-identifying
/// diagnostics so feedback can be triaged by app version and device.
public struct Feedback: Codable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let message: String
    public let appVersion: String?
    public let build: String?
    public let systemVersion: String?
    public let deviceModel: String?
    public let locale: String?
    public let deviceId: String?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        category: String,
        message: String,
        appVersion: String? = nil,
        build: String? = nil,
        systemVersion: String? = nil,
        deviceModel: String? = nil,
        locale: String? = nil,
        deviceId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.message = message
        self.appVersion = appVersion
        self.build = build
        self.systemVersion = systemVersion
        self.deviceModel = deviceModel
        self.locale = locale
        self.deviceId = deviceId
        self.createdAt = createdAt
    }
}
