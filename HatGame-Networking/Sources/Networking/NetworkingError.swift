//
//  NetworkingError.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Foundation

public enum NetworkingError: Error, LocalizedError {
    case roomNotFound
    case failedToGenerateRoomCode
    case encodingFailed
    case decodingFailed
    case notAuthorized
    case firebaseNotConfigured
    case timeout
    case unsupportedVersion

    public var errorDescription: String? {
        switch self {
        case .roomNotFound:
            return "Room not found"
        case .failedToGenerateRoomCode:
            return "Failed to generate unique room code"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        case .notAuthorized:
            return "Not authorized to perform this action"
        case .firebaseNotConfigured:
            return "Firebase is not configured. Please check your GoogleService-Info.plist"
        case .timeout:
            return "Operation timed out. Please check your internet connection"
        case .unsupportedVersion:
            return "This room was created by a newer version of Hat Game. Update the app to join it."
        }
    }
}
