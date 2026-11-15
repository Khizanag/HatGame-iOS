//
//  RoomLimits.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// Length caps shared with `database.rules.json`. Text is clamped before it
/// is written, so a long name or word is shortened rather than rejected by a
/// validation rule.
public enum RoomLimits {
    public static let maxNameLength = 100
    public static let maxWordLength = 200
    public static let maxFeedbackLength = 5000

    public static func name(_ text: String) -> String {
        clamp(text, to: maxNameLength)
    }

    public static func word(_ text: String) -> String {
        clamp(text, to: maxWordLength)
    }

    public static func feedback(_ text: String) -> String {
        clamp(text, to: maxFeedbackLength)
    }

    /// Rules count UTF-16 code units, so clamp on those without splitting a
    /// character.
    static func clamp(_ text: String, to limit: Int) -> String {
        guard text.utf16.count > limit else { return text }
        var result = ""
        var count = 0
        for character in text {
            let length = character.utf16.count
            guard count + length <= limit else { break }
            result.append(character)
            count += length
        }
        return result
    }
}
