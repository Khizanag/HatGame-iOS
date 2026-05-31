//
//  SoundPlayer.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 30.05.26.
//

import AVFoundation
import OSLog

private let logger = Logger(subsystem: "com.khizanag.hat-game", category: "SoundPlayer")

/// Centralized, semantic sound effects for the game. Mirrors `DesignBook.Haptics`:
/// callers fire intent-named methods and never touch `AVAudioPlayer` directly.
///
/// Uses the `.playback` audio session category with `.mixWithOthers`, so the
/// time-up cue is audible even when the hardware mute switch is on (it is a
/// requested, essential gameplay signal) while still mixing over any background
/// audio. Users who want silence can disable it in Settings.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var timeUpPlayer: AVAudioPlayer?

    private init() {
        configureSession()
        timeUpPlayer = makePlayer(resource: "time-up", extension: "caf")
    }

    /// Plays when a turn's timer reaches zero. Honors the user's sound setting.
    func playTimeUp() {
        guard AppConfiguration.shared.isTimeUpSoundEnabled else { return }
        play(timeUpPlayer)
    }

    private func play(_ player: AVAudioPlayer?) {
        guard let player else { return }
        activateSession()
        player.currentTime = 0
        player.play()
    }

    private func makePlayer(resource: String, extension ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            logger.error("Missing bundled sound: \(resource).\(ext)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            logger.error("Failed to load sound \(resource).\(ext): \(error.localizedDescription)")
            return nil
        }
    }

    /// Sets the playback category and activates the session eagerly at launch,
    /// so it is ready long before the first turn ends — the first cue is never
    /// dropped waiting on session setup.
    private func configureSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Audio session configuration failed: \(error.localizedDescription)")
        }
        #endif
    }

    /// Re-asserts the active session right before playing, in case an
    /// interruption deactivated it; playback is attempted regardless.
    private func activateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}
