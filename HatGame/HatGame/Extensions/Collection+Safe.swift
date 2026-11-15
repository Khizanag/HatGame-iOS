//
//  Collection+Safe.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

// MARK: - Safe subscript
nonisolated extension Collection {
    /// The element at `index`, or `nil` when the index is out of bounds.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
