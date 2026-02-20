import Foundation
import FirebaseDatabase
import FirebaseCore

protocol ArenaLeaderboardServiceProtocol {
    func recordMatchResult(_ result: ArenaMatchResult, minMatches: Int) async throws
    func fetchTopPlayers(monthKey: String, limit: Int, minMatches: Int) async throws -> [ArenaPlayerMonthlyStats]
    func fetchPlayerStanding(monthKey: String, playerID: String, minMatches: Int) async throws -> ArenaPlayerStanding
}

final class ArenaLeaderboardService: ArenaLeaderboardServiceProtocol {
    private let monthlyResultsRef: DatabaseReference
    private let monthlyLeaderboardRef: DatabaseReference

    init() {
        let options = FirebaseApp.app()?.options
        if let configuredURL = options?.databaseURL, !configuredURL.isEmpty {
            let root = Database.database(url: configuredURL).reference()
            monthlyResultsRef = root.child("arenaMatchResultsMonthly")
            monthlyLeaderboardRef = root.child("arenaLeaderboardMonthly")
        } else if let projectID = options?.projectID, !projectID.isEmpty {
            let fallbackURL = "https://\(projectID)-default-rtdb.firebaseio.com"
            let root = Database.database(url: fallbackURL).reference()
            monthlyResultsRef = root.child("arenaMatchResultsMonthly")
            monthlyLeaderboardRef = root.child("arenaLeaderboardMonthly")
        } else {
            let root = Database.database().reference()
            monthlyResultsRef = root.child("arenaMatchResultsMonthly")
            monthlyLeaderboardRef = root.child("arenaLeaderboardMonthly")
        }
    }

    func recordMatchResult(_ result: ArenaMatchResult, minMatches: Int = 2) async throws {
        let resultPath = monthlyResultsRef
            .child(result.monthKey)
            .child(result.matchID)
            .child(result.playerID)
        try await setValue(resultPath, value: try result.toDictionary())

        let playerRef = monthlyLeaderboardRef
            .child(result.monthKey)
            .child(result.playerID)
        try await runAggregateTransaction(
            playerRef: playerRef,
            incoming: result,
            minMatches: minMatches
        )
    }

    func fetchTopPlayers(monthKey: String, limit: Int, minMatches: Int = 2) async throws -> [ArenaPlayerMonthlyStats] {
        let snapshot = try await readValue(monthlyLeaderboardRef.child(monthKey))
        let all = parseStats(snapshot: snapshot)
        return all
            .filter { $0.gamesPlayed >= minMatches }
            .sorted { leaderboardSort(lhs: $0, rhs: $1) }
            .prefix(limit)
            .map { $0 }
    }

    func fetchPlayerStanding(monthKey: String, playerID: String, minMatches: Int = 2) async throws -> ArenaPlayerStanding {
        let snapshot = try await readValue(monthlyLeaderboardRef.child(monthKey))
        let all = parseStats(snapshot: snapshot).sorted { leaderboardSort(lhs: $0, rhs: $1) }
        let eligible = all.filter { $0.gamesPlayed >= minMatches }
        let player = all.first(where: { $0.playerID == playerID })

        let rank = eligible.firstIndex(where: { $0.playerID == playerID }).map { $0 + 1 }
        let top50Cutoff = eligible.count >= 50 ? eligible[49].averageScore : nil
        let pointsToTop50: Double?
        if let player {
            if let cutoff = top50Cutoff {
                pointsToTop50 = max(0, cutoff - player.averageScore)
            } else {
                pointsToTop50 = nil
            }
        } else {
            pointsToTop50 = nil
        }

        return ArenaPlayerStanding(
            monthKey: monthKey,
            averageScore: player?.averageScore ?? 0,
            gamesPlayed: player?.gamesPlayed ?? 0,
            rank: rank,
            pointsToTop50: pointsToTop50
        )
    }

    private func parseStats(snapshot: DataSnapshot) -> [ArenaPlayerMonthlyStats] {
        guard let dict = snapshot.value as? [String: Any] else { return [] }
        return dict.compactMap { playerID, raw in
            guard let payload = raw as? [String: Any] else { return nil }
            let games = Self.readInt(payload["gamesPlayed"]) ?? 0
            let total = Self.readDouble(payload["totalScore"]) ?? 0
            let average = Self.readDouble(payload["averageScore"]) ?? 0
            let best = Self.readDouble(payload["bestScore"]) ?? 0
            let updated = Self.readDouble(payload["updatedAtEpoch"]) ?? 0
            let month = payload["monthKey"] as? String ?? snapshot.key
            let name = payload["displayName"] as? String ?? "Player"

            return ArenaPlayerMonthlyStats(
                playerID: playerID,
                displayName: name,
                monthKey: month,
                gamesPlayed: games,
                totalScore: total,
                averageScore: average,
                bestScore: best,
                updatedAtEpoch: updated
            )
        }
    }

    private func leaderboardSort(lhs: ArenaPlayerMonthlyStats, rhs: ArenaPlayerMonthlyStats) -> Bool {
        if lhs.averageScore == rhs.averageScore {
            if lhs.gamesPlayed == rhs.gamesPlayed {
                return lhs.updatedAtEpoch < rhs.updatedAtEpoch
            }
            return lhs.gamesPlayed > rhs.gamesPlayed
        }
        return lhs.averageScore > rhs.averageScore
    }

    private func runAggregateTransaction(
        playerRef: DatabaseReference,
        incoming: ArenaMatchResult,
        minMatches: Int
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            playerRef.runTransactionBlock({ current -> TransactionResult in
                var payload = current.value as? [String: Any] ?? [:]
                let existingGames = Self.readInt(payload["gamesPlayed"]) ?? 0
                let existingTotal = Self.readDouble(payload["totalScore"]) ?? 0
                let existingBest = Self.readDouble(payload["bestScore"]) ?? 0

                let games = existingGames + 1
                let total = existingTotal + incoming.score
                let average = total / Double(max(games, 1))
                let best = max(existingBest, incoming.score)
                let eligible = games >= minMatches

                payload["playerID"] = incoming.playerID
                payload["displayName"] = incoming.displayName
                payload["monthKey"] = incoming.monthKey
                payload["gamesPlayed"] = games
                payload["totalScore"] = total
                payload["averageScore"] = average
                payload["bestScore"] = best
                payload["eligible"] = eligible
                payload["sortScore"] = -average
                payload["updatedAtEpoch"] = incoming.createdAtEpoch

                current.value = payload
                return .success(withValue: current)
            }) { error, _, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func setValue(_ ref: DatabaseReference, value: Any) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func readValue(_ ref: DatabaseReference) async throws -> DataSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DataSnapshot, Error>) in
            ref.observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot)
            }
        }
    }

    private static func readInt(_ raw: Any?) -> Int? {
        if let intVal = raw as? Int { return intVal }
        if let num = raw as? NSNumber { return num.intValue }
        return nil
    }

    private static func readDouble(_ raw: Any?) -> Double? {
        if let doubleVal = raw as? Double { return doubleVal }
        if let intVal = raw as? Int { return Double(intVal) }
        if let num = raw as? NSNumber { return num.doubleValue }
        return nil
    }
}

private extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Encoding", code: 1)
        }
        return object
    }
}
