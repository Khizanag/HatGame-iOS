//
//  Networking.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import FirebaseCore
import FirebaseDatabase
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.khizanag.hat-game", category: "Networking")

public enum Networking {
    public static func configure() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            logger.warning(
                """
                GoogleService-Info.plist not found. Firebase features are disabled.
                Download it from https://console.firebase.google.com/ and add it to the app bundle.
                """
            )
            return
        }

        FirebaseApp.configure()

        // Realtime Database needs a DATABASE_URL in the plist. Without it the SDK
        // emits a cryptic "connection was forcefully killed by the server"
        // warning and silently never connects. Detect it up front instead.
        guard let databaseURL = FirebaseApp.app()?.options.databaseURL, !databaseURL.isEmpty else {
            logger.error(
                """
                Firebase Realtime Database URL is missing from GoogleService-Info.plist.
                To fix:
                  1. Open Firebase Console → project hat-game-e050f → Realtime Database, \
                and click "Create Database" if it doesn't exist yet.
                  2. Re-download GoogleService-Info.plist from project settings; the \
                fresh file will include DATABASE_URL.
                  3. Replace HatGame/HatGame/GoogleService-Info.plist with the new file.
                Online play stays disabled until this is done.
                """
            )
            return
        }

        // Offline persistence + an explicit goOnline so writes resume cleanly
        // after the app returns from background.
        Database.database().isPersistenceEnabled = true
        Database.database().goOnline()
        logger.info("Firebase Realtime Database configured at \(databaseURL, privacy: .public)")
    }

    /// True once `FirebaseApp.configure()` has run and the database URL is set.
    /// Online flows should gate themselves on this before issuing reads/writes.
    public static var isConfigured: Bool {
        guard let app = FirebaseApp.app(),
              let url = app.options.databaseURL else { return false }
        return !url.isEmpty
    }
}

// Re-export models for convenience
@_exported import struct Foundation.UUID
