import Foundation

struct SoloLeaderboardEntry: Codable, Identifiable {
    let id: String
    let difficultyRawValue: String
    let timeSeconds: Int
    let livesLeft: Int
    let createdAtEpoch: TimeInterval

    var difficultyTitle: String {
        SudokuDifficulty(rawValue: difficultyRawValue)?.title ?? difficultyRawValue.capitalized
    }
}

struct AppSettings: Codable {
    var profileName: String = "Player"
    var profileImageData: Data?
    var musicVolume: Double = 0.7
    var fxVolume: Double = 0.8
    var hapticsEnabled: Bool = true
    var nameChangeHistoryISO8601: [String] = []
    var soloLeaderboard: [SoloLeaderboardEntry] = []

    var privacyURL: String = "https://example.com/privacy"
    var dataUsageURL: String = "https://example.com/data-usage"
}
