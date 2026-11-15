//
//  SoundPlaying.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

/// The game sounds the engine triggers; `SoundPlayer` is the real one.
@MainActor
protocol SoundPlaying {
    func playTimeUp()
}

// MARK: - SoundPlayer + SoundPlaying
extension SoundPlayer: SoundPlaying {}
