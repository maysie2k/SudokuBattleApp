import Foundation

struct ArenaMatchResult: Codable {
    var playerID: String
    var displayName: String
    var matchID: String
    var monthKey: String
    var completedSquares: Int
    var completionRatio: Double
    var elapsedSeconds: Double
    var scoringTimeSeconds: Double
    var didFinish: Bool
    var errors: Int
    var maxStreak: Int
    var score: Double
    var createdAtEpoch: TimeInterval
}

struct ArenaPlayerMonthlyStats: Codable, Identifiable {
    var id: String { playerID }
    var playerID: String
    var displayName: String
    var monthKey: String
    var gamesPlayed: Int
    var totalScore: Double
    var averageScore: Double
    var bestScore: Double
    var updatedAtEpoch: TimeInterval
}

struct ArenaPlayerStanding {
    var monthKey: String
    var averageScore: Double
    var gamesPlayed: Int
    var rank: Int?
    var pointsToTop50: Double?
}

enum ArenaLeaderboardMonth {
    static func currentKey(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    static func displayName(for monthKey: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_GB")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM"

        guard let date = parser.date(from: monthKey) else { return monthKey }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).uppercased()
    }
}

enum ArenaIdentity {
    private static let stableIDKey = "arena.stablePlayerID"
    private static var cachedSessionID: String?

    static func stablePlayerID() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: stableIDKey), !existing.isEmpty {
            return existing
        }
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        let stable = "p-\(suffix)"
        defaults.set(stable, forKey: stableIDKey)
        return stable
    }

    static func sessionPlayerID(baseStableID: String? = nil) -> String {
        if let cachedSessionID, !cachedSessionID.isEmpty {
            return cachedSessionID
        }
        let stable = baseStableID ?? stablePlayerID()
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
        let sessionID = "\(stable)-s\(suffix)"
        cachedSessionID = sessionID
        return sessionID
    }
}
