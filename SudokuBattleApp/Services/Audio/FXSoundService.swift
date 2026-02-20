import Foundation
import AVFoundation

final class FXSoundService {
    static let shared = FXSoundService()

    private let settingsStore: AppSettingsStore
    private var correctPlayer: AVAudioPlayer?
    private var incorrectPlayer: AVAudioPlayer?
    private var powerPushPlayer: AVAudioPlayer?

    init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore
    }

    func playCorrectPlacement() {
        // Do not layer the regular ting over the power-push success effect.
        if powerPushPlayer?.isPlaying == true { return }
        prepareCorrectPlayerIfNeeded()
        guard let correctPlayer else { return }
        correctPlayer.volume = Float(settingsStore.load().fxVolume)
        correctPlayer.currentTime = 0
        correctPlayer.play()
    }

    func playPowerPushSuccess() {
        preparePowerPushPlayerIfNeeded()
        guard let powerPushPlayer else { return }

        // Ensure only the power-push success effect is heard for this action.
        correctPlayer?.stop()
        correctPlayer?.currentTime = 0

        powerPushPlayer.volume = Float(settingsStore.load().fxVolume)
        powerPushPlayer.currentTime = 0
        powerPushPlayer.play()
    }

    func playIncorrectPlacement() {
        prepareIncorrectPlayerIfNeeded()
        guard let incorrectPlayer else { return }
        incorrectPlayer.volume = Float(settingsStore.load().fxVolume)
        incorrectPlayer.currentTime = 0
        incorrectPlayer.play()
    }

    private func prepareCorrectPlayerIfNeeded() {
        guard correctPlayer == nil else { return }

        guard let url = Bundle.main.url(forResource: "freesound_community-news-ting-6832", withExtension: "mp3", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "freesound_community-news-ting-6832", withExtension: "mp3")
        else {
            print("[FXSoundService] Missing fx track freesound_community-news-ting-6832.mp3")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.prepareToPlay()
            correctPlayer = player
        } catch {
            print("[FXSoundService] Could not load correct placement FX: \(error)")
        }
    }

    private func preparePowerPushPlayerIfNeeded() {
        guard powerPushPlayer == nil else { return }

        guard let url = Bundle.main.url(forResource: "yodguard-level-up-skill-upgrade-4-387909", withExtension: "mp3", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "yodguard-level-up-skill-upgrade-4-387909", withExtension: "mp3")
        else {
            print("[FXSoundService] Missing power-push fx track yodguard-level-up-skill-upgrade-4-387909.mp3")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.prepareToPlay()
            powerPushPlayer = player
        } catch {
            print("[FXSoundService] Could not load power-push FX: \(error)")
        }
    }

    private func prepareIncorrectPlayerIfNeeded() {
        guard incorrectPlayer == nil else { return }

        guard let url = Bundle.main.url(forResource: "soundreality-battle-pop-424581", withExtension: "mp3", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "soundreality-battle-pop-424581", withExtension: "mp3")
        else {
            print("[FXSoundService] Missing incorrect placement FX track soundreality-battle-pop-424581.mp3")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.prepareToPlay()
            incorrectPlayer = player
        } catch {
            print("[FXSoundService] Could not load incorrect placement FX: \(error)")
        }
    }
}
