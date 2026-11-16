//
//  SessionAnimations.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation

/// Decorative sequences that play in full only the first time per app
/// session; later games get a short version (HIG motion.md: don't make
/// people wait through the same animation again). Both stay skippable.
@MainActor
enum SessionAnimations {
    /// The hat shuffle before a game starts.
    static var hasPlayedShuffle = false
    /// The word draw of the automatic word source.
    static var hasPlayedWordDraw = false
}
