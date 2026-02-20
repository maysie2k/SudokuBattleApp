import Foundation
import AVFoundation

final class ArenaBackgroundMusicService: NSObject, AVAudioPlayerDelegate {
    static let shared = ArenaBackgroundMusicService()

    private let settingsStore: AppSettingsStore
    private var players: [AVAudioPlayer] = []
    private var trackIndex = 0
    private var isPlaying = false

    init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore
        super.init()
    }

    func startIfNeeded() {
        guard !isPlaying else {
            updateVolume()
            return
        }
        preparePlayersIfNeeded()
        guard !players.isEmpty else { return }
        isPlaying = true
        playCurrentTrack()
    }

    func stop() {
        isPlaying = false
        players.forEach { $0.stop() }
        trackIndex = 0
    }

    func updateVolume() {
        let volume = Float(settingsStore.load().musicVolume)
        players.forEach { $0.volume = volume }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard isPlaying, !players.isEmpty else { return }
        trackIndex = (trackIndex + 1) % players.count
        playCurrentTrack()
    }

    private func preparePlayersIfNeeded() {
        guard players.isEmpty else { return }

        let names = ["Cognitive Sprint", "Cognitive Sprint-2"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "Resources")
                ?? Bundle.main.url(forResource: name, withExtension: "mp3")
            else {
                print("[ArenaBackgroundMusicService] Missing track: \(name).mp3")
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = 0
                player.delegate = self
                player.prepareToPlay()
                players.append(player)
            } catch {
                print("[ArenaBackgroundMusicService] Could not load \(name).mp3: \(error)")
            }
        }

        updateVolume()
    }

    private func playCurrentTrack() {
        guard isPlaying, !players.isEmpty else { return }
        players.indices.forEach { idx in
            if idx != trackIndex {
                players[idx].stop()
                players[idx].currentTime = 0
            }
        }

        let player = players[trackIndex]
        player.currentTime = 0
        updateVolume()
        player.play()
    }
}
