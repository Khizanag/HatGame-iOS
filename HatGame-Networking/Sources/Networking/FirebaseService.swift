//
//  FirebaseService.swift
//  Networking
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import FirebaseCore
import FirebaseDatabase
import Foundation
import GameCore
import OSLog

private let logger = Logger(subsystem: "com.khizanag.hat-game", category: "FirebaseService")

public final class FirebaseService: @unchecked Sendable {
    public static let shared = FirebaseService()

    /// Every read and write is bounded. With offline persistence enabled a
    /// write's completion waits for the server, so without a bound an
    /// offline device spins forever.
    enum Timeouts {
        static let read: Duration = .seconds(10)
        static let write: Duration = .seconds(10)
        /// Transactions may round-trip more than once under contention.
        static let transaction: Duration = .seconds(15)
    }

    private var database: Database {
        Database.database()
    }

    private var roomsRef: DatabaseReference {
        database.reference().child("rooms")
    }

    private var feedbackRef: DatabaseReference {
        database.reference().child("feedback")
    }

    private init() {
        // Lazy initialization - database accessed only when needed
    }

    public var isAvailable: Bool {
        // Requires both FirebaseApp.configure() to have run *and* a DATABASE_URL
        // in the bundle — operations on the realtime database silently fail
        // without the URL.
        guard let url = FirebaseApp.app()?.options.databaseURL else { return false }
        return !url.isEmpty
    }

    // MARK: - Room Operations
    /// Creates the room unless its code is already in use. Returns `false`
    /// on a collision so the caller can draw another code — a plain write
    /// would silently replace someone else's room.
    public func createRoom(_ room: GameRoom) async throws -> Bool {
        try await transact { [self] in
            try await runCreateIfAbsent(on: roomsRef.child(room.id), value: room)
        }
    }

    public func getRoom(id: String) async throws -> GameRoom? {
        try await read { [self] in
            let snapshot = try await roomsRef.child(id).getData()
            guard snapshot.exists(), let value = snapshot.value else { return nil }
            return try FirebaseCoding.decode(GameRoom.self, from: value)
        }
    }

    public func deleteRoom(id: String) async throws {
        try await write { [self] in
            _ = try await roomsRef.child(id).removeValue()
        }
    }

    public func observeRoom(id: String, onChange: @escaping (RoomSnapshot) -> Void) -> DatabaseHandle? {
        guard isAvailable else {
            onChange(.missing)
            return nil
        }
        return roomsRef.child(id).observe(.value) { snapshot in
            let classified = RoomSnapshot(storedValue: snapshot.exists() ? snapshot.value : nil)
            if case .unreadable = classified {
                logger.error("Failed to decode room \(id, privacy: .public)")
            }
            onChange(classified)
        }
    }

    public func removeObserver(handle: DatabaseHandle, forRoomId roomId: String) {
        roomsRef.child(roomId).removeObserver(withHandle: handle)
    }

    // MARK: - Player Operations
    public func addPlayer(_ player: OnlinePlayer, toRoomId roomId: String) async throws {
        try await update(roomId: roomId, RoomWrites.addPlayer(player))
    }

    public func setPlayerFlag(
        _ flag: PlayerFlag,
        to value: Bool,
        playerId: String,
        inRoomId roomId: String
    ) async throws {
        try await update(roomId: roomId, RoomWrites.playerFlag(flag, to: value, playerId: playerId))
    }

    // MARK: - Presence
    /// Reports this client's connection to the database: `true` once
    /// connected, `false` whenever the link drops. Fires immediately.
    public func observeConnection(_ onChange: @escaping (Bool) -> Void) -> DatabaseHandle? {
        guard isAvailable else { return nil }
        return database.reference(withPath: ".info/connected").observe(.value) { snapshot in
            onChange(snapshot.value as? Bool == true)
        }
    }

    public func removeConnectionObserver(_ handle: DatabaseHandle) {
        database.reference(withPath: ".info/connected").removeObserver(withHandle: handle)
    }

    /// Marks the player online and asks the server to mark them offline the
    /// moment this client's connection drops — including when the app is
    /// suspended or killed.
    public func armPresence(playerId: String, roomId: String) async throws {
        try await write { [self] in
            let flag = playerFlagRef(.isConnected, playerId: playerId, roomId: roomId)
            _ = try await flag.onDisconnectSetValue(false)
            _ = try await flag.setValue(true)
        }
    }

    /// Cancels the pending server-side offline write. `markOffline` also
    /// writes `false` now — only for a player who stays in an existing room,
    /// since writing to a removed player would recreate a partial node.
    public func disarmPresence(playerId: String, roomId: String, markOffline: Bool) async throws {
        try await write { [self] in
            let flag = playerFlagRef(.isConnected, playerId: playerId, roomId: roomId)
            _ = try await flag.cancelDisconnectOperations()
            if markOffline {
                _ = try await flag.setValue(false)
            }
        }
    }

    public func removePlayer(playerId: String, fromRoomId roomId: String) async throws {
        try await write { [self] in
            _ = try await roomsRef.child(roomId).child("players").child(playerId).removeValue()
        }
    }

    // MARK: - Team Operations
    public func addTeam(_ team: OnlineTeam, toRoomId roomId: String) async throws {
        try await update(roomId: roomId, RoomWrites.addTeam(team))
    }

    /// Deletes the team and clears every member's `teamId` in one
    /// multi-path update, so no player is left pointing at a missing team.
    public func removeTeam(teamId: String, unassigning memberIds: [String], fromRoomId roomId: String) async throws {
        try await update(roomId: roomId, RoomWrites.removeTeam(teamId, unassigning: memberIds))
    }

    /// Atomically reassigns a player to a team: clears the previous team's
    /// playerIds, sets the player's teamId, and appends the player to the
    /// new team's playerIds. Pass `nil` for `newTeamId` to leave the player
    /// without a team. Single multi-path update so the two sides of the
    /// relationship cannot diverge.
    public func reassignPlayerToTeam(
        playerId: String,
        previousTeamId: String?,
        newTeamId: String?,
        teams: [OnlineTeam],
        inRoomId roomId: String
    ) async throws {
        let updates = RoomWrites.reassign(
            playerId: playerId,
            previousTeamId: previousTeamId,
            newTeamId: newTeamId,
            teams: teams
        )
        try await update(roomId: roomId, updates)
    }

    // MARK: - Word Operations
    /// Writes `words` AND flips every listed player's `hasSubmittedWords`
    /// flag in a single multi-path update — all-or-nothing, so a failure
    /// leaves no partial state to recover from, and it touches only the flag
    /// leaf (never a full player node), so concurrent edits to other fields
    /// are not clobbered. Serves both a player's own submission and the
    /// host's automatic fill for everyone.
    public func fillWords(
        _ words: [OnlineWord],
        markSubmittedPlayerIds playerIds: [String],
        toRoomId roomId: String
    ) async throws {
        try await update(roomId: roomId, RoomWrites.fillWords(words, markSubmitted: playerIds))
    }

    /// The room's word pool. A malformed entry throws rather than silently
    /// shrinking the hat.
    public func getWords(forRoomId roomId: String) async throws -> [OnlineWord] {
        try await read { [self] in
            let snapshot = try await roomsRef.child(roomId).child("words").getData()
            guard snapshot.exists(), let value = snapshot.value else { return [] }
            return try FirebaseCoding.decode([String: OnlineWord].self, from: value)
                .sorted { $0.key < $1.key }
                .map(\.value)
        }
    }

    // MARK: - Game State Operations
    /// Replaces the room's game state with `transform(liveState)` atomically.
    /// `transform` runs against the server's current value — re-running if
    /// another client wrote first — and returns `nil` to reject. Returns the
    /// committed state, or `nil` when rejected.
    public func transactGameState(
        roomId: String,
        _ transform: @escaping @Sendable (OnlineGameState?) -> OnlineGameState?
    ) async throws -> OnlineGameState? {
        try await transact { [self] in
            try await runTransaction(on: roomsRef.child(roomId).child("gameState"), transform)
        }
    }

    public func updateRoomStatus(_ status: RoomStatus, forRoomId roomId: String) async throws {
        try await update(roomId: roomId, RoomWrites.status(status))
    }

    // MARK: - Feedback
    /// Create-only: the rules refuse to overwrite an existing entry.
    public func submitFeedback(_ feedback: Feedback) async throws {
        let bounded = Feedback(
            id: feedback.id,
            category: feedback.category,
            message: RoomLimits.feedback(feedback.message),
            appVersion: feedback.appVersion,
            build: feedback.build,
            systemVersion: feedback.systemVersion,
            deviceModel: feedback.deviceModel,
            locale: feedback.locale,
            deviceId: feedback.deviceId,
            createdAt: feedback.createdAt
        )
        let box = UpdatesBox(updates: try FirebaseCoding.dictionary(from: bounded))
        try await write { [self] in
            _ = try await feedbackRef.child(bounded.id).setValue(box.updates)
        }
    }
}

// MARK: - Helpers
private extension FirebaseService {
    func playerFlagRef(_ flag: PlayerFlag, playerId: String, roomId: String) -> DatabaseReference {
        roomsRef.child(roomId).child("players").child(playerId).child(flag.rawValue)
    }

    /// Sends one multi-path update built by `RoomWrites`.
    func update(roomId: String, _ updates: RoomWrites.Updates) async throws {
        let box = UpdatesBox(updates: updates)
        try await write { [self] in
            _ = try await roomsRef.child(roomId).updateChildValues(box.updates)
        }
    }

    func read<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        guard isAvailable else { throw NetworkingError.firebaseNotConfigured }
        return try await withTimeout(Timeouts.read, operation: operation)
    }

    func write(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        guard isAvailable else { throw NetworkingError.firebaseNotConfigured }
        try await withTimeout(Timeouts.write, operation: operation)
    }

    func transact<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        guard isAvailable else { throw NetworkingError.firebaseNotConfigured }
        return try await withTimeout(Timeouts.transaction, operation: operation)
    }
}

/// Carries a built update into the timed write. The dictionary holds only
/// JSON-compatible Foundation values and is never mutated after building.
private struct UpdatesBox: @unchecked Sendable {
    let updates: RoomWrites.Updates
}
