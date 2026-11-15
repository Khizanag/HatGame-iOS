//
//  PlayCompletionReason.swift
//  HatGame
//
//  Created by Giga Khizanishvili
//

/// Why a turn ended.
nonisolated enum PlayCompletionReason: String, Codable, Sendable {
    /// The clock reached zero.
    case timeExpired
    /// The team gave up — scored and rotated exactly like `timeExpired`.
    case gaveUp
    /// The last word in the hat was guessed, which ends the round.
    case allWordsGuessed
}
