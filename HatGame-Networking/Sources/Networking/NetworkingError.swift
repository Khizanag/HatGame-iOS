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
            // The developer diagnostic is logged by Networking.configure().
            return "Online play isn't available in this version of the app. Play Nearby still works."
        case .timeout:
            return "Operation timed out. Please check your internet connection"
        case .unsupportedVersion:
            return "This room was created by a newer version of Hat Game. Update the app to join it."
        }
    }
}

/// True when a write that failed with `error` may still reach the server.
/// Offline persistence queues writes, so a timeout or a cancelled wait is a
/// write in flight, not a write refused.
func writeMayStillLand(_ error: any Error) -> Bool {
    error as? NetworkingError == .timeout || error is CancellationError
}
