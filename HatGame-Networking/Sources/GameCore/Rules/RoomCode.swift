//
//  RoomCode.swift
//  GameCore
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// Six characters from an alphabet without the look-alikes I, O, 0 and 1.
/// `database.rules.json` accepts exactly this shape under `/rooms`.
public enum RoomCode {
    public static let alphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    public static let length = 6

    public static func random() -> String {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    public static func random<Generator: RandomNumberGenerator>(using generator: inout Generator) -> String {
        String((0..<length).map { _ in alphabet[Int.random(in: alphabet.indices, using: &generator)] })
    }

    /// Uppercases typed input and keeps only characters a code can contain,
    /// up to the code length.
    public static func sanitized(_ input: String) -> String {
        String(input.uppercased().filter(alphabet.contains).prefix(length))
    }

    public static func isValid(_ code: String) -> Bool {
        code.count == length && code.allSatisfy(alphabet.contains)
    }
}
