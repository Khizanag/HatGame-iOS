//
//  AuthGate.swift
//  Networking
//
//  Created by Giga Khizanishvili on 31.08.26.
//

import FirebaseAuth
import Foundation

/// Holds the anonymous Firebase session every read and write depends on.
///
/// The database rules reject unauthenticated access, so a token has to exist
/// before any operation reaches the server. Firebase persists the anonymous
/// user across launches, making this a no-op after the first success.
actor AuthGate {
    static let shared = AuthGate()

    private var signIn: Task<Void, Error>?

    /// Signs in anonymously if there is no session yet. Concurrent callers
    /// share a single attempt rather than racing to create separate users.
    func ensureSignedIn() async throws {
        if Auth.auth().currentUser != nil { return }

        let task = signIn ?? Task { _ = try await Auth.auth().signInAnonymously() }
        signIn = task

        do {
            try await task.value
        } catch {
            // Drop the shared attempt so the next caller retries instead of
            // replaying this failure forever.
            signIn = nil
            throw NetworkingError.authenticationFailed
        }
    }
}
