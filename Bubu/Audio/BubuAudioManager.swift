//
//  BubuAudioManager.swift
//  Bubu
//

import AVFoundation

/// Looping background music via a single `AVAudioPlayer` instance.
///
/// Lifecycle (driven by `GameView` / `HomeView`):
/// - **Home:** no music (`setGameplayActive(false)` stops playback).
/// - **Gameplay:** music plays when enabled and the app is active.
/// - **Purse overlay:** music keeps playing (game pauses visually; audio unchanged).
/// - **Game over:** music keeps playing until the player leaves the run.
/// - **App background:** pauses; resumes from the same position when active again.
@MainActor
final class BubuAudioManager {
    static let shared = BubuAudioManager()

    /// Bundle resource name without extension. Add `bubu-theme.mp3` or `bubu-theme.m4a` to the app target.
    static let backgroundMusicResourceName = "bubu-theme"

    private var player: AVAudioPlayer?

    private var musicEnabled = true
    private var gameplayActive = false
    private var appActive = true

    private let defaultVolume: Float = 0.3

    private init() {
        configureAudioSession()
    }

    func setMusicEnabled(_ enabled: Bool) {
        guard musicEnabled != enabled else { return }
        musicEnabled = enabled
        syncPlayback()
    }

    func setGameplayActive(_ active: Bool) {
        guard gameplayActive != active else { return }
        gameplayActive = active
        if !active {
            stop()
        } else {
            syncPlayback()
        }
    }

    func setAppActive(_ active: Bool) {
        guard appActive != active else { return }
        appActive = active
        syncPlayback()
    }

    func setVolume(_ volume: Float) {
        player?.volume = max(0, min(1, volume))
    }

    // MARK: - Playback

    private func syncPlayback() {
        guard musicEnabled, gameplayActive, appActive else {
            pause()
            return
        }
        playIfNeeded()
    }

    private func playIfNeeded() {
        guard let player = loadPlayerIfNeeded() else { return }
        guard !player.isPlaying else { return }
        player.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
    }

    // MARK: - Setup

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("[BubuAudioManager] Audio session setup failed: \(error)")
            #endif
        }
    }

    private func loadPlayerIfNeeded() -> AVAudioPlayer? {
        if let player { return player }

        guard let url = Self.backgroundMusicURL else {
            #if DEBUG
            print(
                "[BubuAudioManager] Missing '\(Self.backgroundMusicResourceName).mp3' or " +
                "'\(Self.backgroundMusicResourceName).m4a' in app bundle."
            )
            #endif
            return nil
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = defaultVolume
            newPlayer.prepareToPlay()
            player = newPlayer
            return newPlayer
        } catch {
            #if DEBUG
            print("[BubuAudioManager] Failed to load background music: \(error)")
            #endif
            return nil
        }
    }

    private static var backgroundMusicURL: URL? {
        for ext in ["mp3", "m4a"] {
            if let url = Bundle.main.url(forResource: backgroundMusicResourceName, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
