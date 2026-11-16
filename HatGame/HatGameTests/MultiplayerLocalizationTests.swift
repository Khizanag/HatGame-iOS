//
//  MultiplayerLocalizationTests.swift
//  HatGameTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import HatGame
import Networking
import Testing

/// Resolves the online and nearby strings against the built bundle, so a
/// missing or misspelled catalog entry fails here instead of rendering as
/// its raw key.
@MainActor
@Suite("Multiplayer localization")
struct MultiplayerLocalizationTests {
    nonisolated static let languages = ["en", "ka"]

    static let keys: [String] = [
        "common.buttons.close",
        "createTeam.confirm",
        "createTeam.discard.confirm",
        "createTeam.discard.keepEditing",
        "createTeam.discard.title",
        "error.connection.timedOut",
        "error.generic",
        "error.nearby.declined",
        "error.nearby.notBrowsing",
        "error.nearby.refused",
        "error.nearby.timedOut",
        "error.nearby.unsupportedAction",
        "error.room.createFailed",
        "error.room.dataInvalid",
        "error.room.full",
        "error.room.gameStarted",
        "error.room.hostOnly",
        "error.room.notEnoughPlayers",
        "error.room.notEnoughTeams",
        "error.room.notFound",
        "error.room.teamFull",
        "error.title.connection",
        "error.title.createRoom",
        "error.title.createTeam",
        "error.title.deleteTeam",
        "error.title.hostGame",
        "error.title.joinRoom",
        "error.title.joinTeam",
        "error.title.leaveRoom",
        "error.title.leaveTeam",
        "error.title.removePlayer",
        "error.title.startGame",
        "error.title.submitWords",
        "joinRoom.codeCharactersHint",
        "lobby.away",
        "lobby.deleteTeam",
        "lobby.deleteTeam.confirm",
        "lobby.deleteTeam.message",
        "lobby.deleteTeam.title",
        "lobby.inTeam",
        "lobby.inTeam.unnamed",
        "lobby.leave.confirm",
        "lobby.leave.title",
        "lobby.nearbyHint",
        "lobby.removePlayer",
        "local.session.gameInProgress",
        "local.session.versionMismatch",
        "local.session.versionMismatch.title",
        "multiplayer.nameRequired",
        "online.session.closed",
        "online.session.closed.message",
        "online.startWithSubmittedWords",
        "online.unavailable",
        "online.unsupported.message",
        "online.unsupported.title",
        "onlineWordInput.duplicate",
        "onlineWordInput.removeWord",
        "session.leave",
        "session.leave.nearby.inGame",
        "session.leave.nearby.lobby",
        "session.leave.online.inGame",
    ]

    static let errors: [any Error] = [
        NetworkingError.roomNotFound,
        NetworkingError.failedToGenerateRoomCode,
        NetworkingError.encodingFailed,
        NetworkingError.decodingFailed,
        NetworkingError.notAuthorized,
        NetworkingError.firebaseNotConfigured,
        NetworkingError.timeout,
        NetworkingError.unsupportedVersion,
        RoomError.gameAlreadyStarted,
        RoomError.roomFull,
        RoomError.teamFull,
        RoomError.notEnoughPlayers,
        RoomError.notEnoughTeams,
        LocalMultipeerService.ConnectionError.notBrowsing,
        LocalMultipeerService.ConnectionError.declined,
        LocalMultipeerService.ConnectionError.timedOut,
        LocalRoomManager.LocalError.notImplementedForLocal,
        LocalRoomManager.LocalError.hostOnly,
    ]

    @Test(arguments: languages)
    func everyKeyResolves(language: String) throws {
        let bundle = try Self.bundle(language)
        for key in Self.keys {
            let value = String(localized: String.LocalizationValue(key), bundle: bundle)
            #expect(value != key, "\(key) is missing in \(language)")
            #expect(!value.isEmpty, "\(key) is empty in \(language)")
        }
    }

    @Test func pluralsPickTheEnglishForm() throws {
        let bundle = try Self.bundle("en")
        #expect(String(localized: "game.turnResults.wordsUnit \(1)", bundle: bundle) == "word")
        #expect(String(localized: "game.turnResults.wordsUnit \(3)", bundle: bundle) == "words")
        #expect(String(localized: "game.wordsRemaining \(1)", bundle: bundle) == "1 word left in the hat")
        #expect(String(localized: "game.wordsRemaining \(4)", bundle: bundle) == "4 words left in the hat")
        #expect(String(localized: "game.currentScoreLabel \(1)", bundle: bundle) == "Current score: 1 point")
        #expect(String(localized: "game.currentScoreLabel \(7)", bundle: bundle) == "Current score: 7 points")
        #expect(
            String(localized: "onlineSpectator.score.accessibility \(1)", bundle: bundle)
                == "1 word guessed this turn"
        )
    }

    @Test func georgianKeepsTheSingularAfterNumbers() throws {
        let bundle = try Self.bundle("ka")
        #expect(String(localized: "game.turnResults.wordsUnit \(1)", bundle: bundle) == "სიტყვა")
        #expect(String(localized: "game.turnResults.wordsUnit \(5)", bundle: bundle) == "სიტყვა")
        #expect(String(localized: "game.wordsRemaining \(5)", bundle: bundle) == "ქუდში დარჩა 5 სიტყვა")
    }

    /// Every package error maps to its own catalog message, never a raw key
    /// or the generic fallback.
    @Test func everyNetworkErrorHasItsOwnMessage() {
        for error in Self.errors {
            let message = NetworkErrorMessage.message(for: error)
            #expect(!Self.keys.contains(message), "\(error) shows a raw key")
            #expect(message != NetworkErrorMessage.message(for: CocoaError(.featureUnsupported)), "\(error) is generic")
        }
    }

    @Test func firebasePermissionDeniedReadsAsAMissingRoom() {
        let denied = NSError(domain: "com.firebase", code: 1)
        let notFound = NetworkErrorMessage.message(for: NetworkingError.roomNotFound)
        #expect(NetworkErrorMessage.message(for: denied) == notFound)
    }

    @Test func nearbyVersionMismatchIsNeutral() {
        let online = NetworkErrorMessage.message(for: NetworkingError.unsupportedVersion)
        let nearby = NetworkErrorMessage.message(for: NetworkingError.unsupportedVersion, transport: .nearby)
        #expect(online != nearby)
        #expect(nearby == NetworkErrorMessage.message(for: HelloRejection.unsupportedVersion))
    }

    private static func bundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }
}
