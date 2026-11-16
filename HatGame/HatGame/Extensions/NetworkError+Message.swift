//
//  NetworkError+Message.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
import Networking

/// Maps errors from the online and nearby transports to messages in the
/// in-app language. The Networking package's own descriptions are English
/// developer text, so nothing from it reaches the screen directly.
enum NetworkErrorMessage {
    /// Which transport raised the error. A version mismatch reads differently
    /// online (the room is newer) than nearby (either device may be older).
    enum Transport {
        case online
        case nearby
    }

    static func message(for error: any Error, transport: Transport = .online) -> String {
        switch error {
        case let error as NetworkingError:
            message(for: error, transport: transport)
        case let error as RoomError:
            message(for: error)
        case let error as LocalMultipeerService.ConnectionError:
            message(for: error)
        case let error as LocalRoomManager.LocalError:
            message(for: error)
        default:
            localized(isPermissionDenied(error) ? "error.room.notFound" : "error.generic")
        }
    }

    /// Why the nearby host refused this device's hello.
    static func message(for rejection: HelloRejection) -> String {
        switch rejection {
        case .unsupportedVersion: localized("local.session.versionMismatch")
        case .gameInProgress: localized("local.session.gameInProgress")
        case .refused: localized("error.nearby.refused")
        }
    }
}

// MARK: - Cases
private extension NetworkErrorMessage {
    static func message(for error: NetworkingError, transport: Transport) -> String {
        switch error {
        case .roomNotFound: localized("error.room.notFound")
        case .failedToGenerateRoomCode: localized("error.room.createFailed")
        case .encodingFailed, .decodingFailed: localized("error.room.dataInvalid")
        case .notAuthorized: localized("error.room.hostOnly")
        case .firebaseNotConfigured: localized("online.unavailable")
        case .timeout: localized("error.connection.timedOut")
        case .unsupportedVersion where transport == .online: localized("online.unsupported.message")
        case .unsupportedVersion: localized("local.session.versionMismatch")
        }
    }

    static func message(for error: RoomError) -> String {
        switch error {
        case .gameAlreadyStarted: localized("error.room.gameStarted")
        case .roomFull: localized("error.room.full")
        case .teamFull: localized("error.room.teamFull")
        case .notEnoughPlayers: localized("error.room.notEnoughPlayers")
        case .notEnoughTeams: localized("error.room.notEnoughTeams")
        }
    }

    static func message(for error: LocalMultipeerService.ConnectionError) -> String {
        switch error {
        case .notBrowsing: localized("error.nearby.notBrowsing")
        case .declined: localized("error.nearby.declined")
        case .timedOut: localized("error.nearby.timedOut")
        }
    }

    static func message(for error: LocalRoomManager.LocalError) -> String {
        switch error {
        case .notImplementedForLocal: localized("error.nearby.unsupportedAction")
        case .hostOnly: localized("error.room.hostOnly")
        }
    }

    /// Firebase reports a security-rules refusal as `com.firebase` code 1.
    /// The rules only refuse reads and writes for rooms that are gone or
    /// that this device may no longer touch, so it reads as a missing room.
    static func isPermissionDenied(_ error: any Error) -> Bool {
        let error = error as NSError
        return error.domain == "com.firebase" && error.code == 1
    }
}
