import Foundation

protocol ArenaMatchmakerServiceProtocol {
    func enterQueue(
        playerID: String,
        profileName: String,
        profileImageBase64: String?,
        difficulty: SudokuDifficulty
    ) async throws -> MatchState
    func leaveQueue(playerID: String) async
}

import FirebaseDatabase
import FirebaseCore

final class ArenaMatchmakerService: ArenaMatchmakerServiceProtocol {
    private let matchesRef: DatabaseReference
    private let queueRef: DatabaseReference
    private let generator = SudokuGenerator()

    init() {
        FirebaseServerClock.shared.start()
        let options = FirebaseApp.app()?.options
        if let configuredURL = options?.databaseURL, !configuredURL.isEmpty {
            let root = Database.database(url: configuredURL).reference()
            matchesRef = root.child("matches")
            queueRef = root.child("arenaQueue")
        } else if let projectID = options?.projectID, !projectID.isEmpty {
            let fallbackURL = "https://\(projectID)-default-rtdb.firebaseio.com"
            let root = Database.database(url: fallbackURL).reference()
            matchesRef = root.child("matches")
            queueRef = root.child("arenaQueue")
        } else {
            let root = Database.database().reference()
            matchesRef = root.child("matches")
            queueRef = root.child("arenaQueue")
        }
    }

    func enterQueue(
        playerID: String,
        profileName: String,
        profileImageBase64: String?,
        difficulty: SudokuDifficulty
    ) async throws -> MatchState {
        let now = FirebaseServerClock.shared.serverNowEpoch()
        let queueEntryMaxAge: TimeInterval = 45
        let queueSnapshot = try await readValue(queueRef)
        let queue = queueSnapshot.value as? [String: Any] ?? [:]
        let ownEntry = queue[playerID] as? [String: Any]
        let ownCreatedAt = Self.parseEpoch(ownEntry?["createdAtEpoch"]) ?? .greatestFiniteMagnitude
        let ownEntryIsStale = ownCreatedAt != .greatestFiniteMagnitude && (now - ownCreatedAt) > queueEntryMaxAge

        if ownEntryIsStale {
            try? await queueRef.child(playerID).removeValueAsync()
        }

        // Pick the oldest waiting opponent for deterministic pairing.
        let opponentCandidates = queue
            .filter { $0.key != playerID }
            .sorted { lhs, rhs in
                let l = Self.parseEpoch((lhs.value as? [String: Any])?["createdAtEpoch"]) ?? .greatestFiniteMagnitude
                let r = Self.parseEpoch((rhs.value as? [String: Any])?["createdAtEpoch"]) ?? .greatestFiniteMagnitude
                return l < r
            }

        for candidate in opponentCandidates {
            guard
                let value = candidate.value as? [String: Any],
                let matchID = value["matchID"] as? String,
                let candidateCreatedAt = Self.parseEpoch(value["createdAtEpoch"]),
                let shared = try await loadSharedMatch(matchID: matchID)
            else {
                // Clean up stale queue entries pointing to missing matches.
                try? await queueRef.child(candidate.key).removeValueAsync()
                continue
            }

            if (now - candidateCreatedAt) > queueEntryMaxAge {
                try? await queueRef.child(candidate.key).removeValueAsync()
                continue
            }

            // Only join matches that are waiting for a second player.
            // If this queue entry points to a full match, remove it as stale.
            // Prefer joining an older waiting player if we also already have a queue entry.
            if shared.winnerPlayerID != nil {
                try? await queueRef.child(candidate.key).removeValueAsync()
                continue
            }

            let candidateIsOlderThanSelf: Bool = {
                guard ownEntry != nil, !ownEntryIsStale else { return true }
                if candidateCreatedAt < ownCreatedAt { return true }
                if candidateCreatedAt > ownCreatedAt { return false }
                // Deterministic tie-breaker prevents both players joining each other simultaneously.
                return candidate.key < playerID
            }()

            let shouldJoinCandidate =
                shared.playerIDs.contains(playerID) ||
                (
                    shared.playerIDs.count < 2 &&
                    (
                        ownEntry == nil ||
                        ownEntryIsStale ||
                        candidateIsOlderThanSelf
                    )
                )

            if shouldJoinCandidate {
                do {
                    let joined = try await joinExisting(
                        matchID: matchID,
                        playerID: playerID,
                        profileName: profileName,
                        profileImageBase64: profileImageBase64
                    )
                    // Remove queue entries only after join succeeds.
                    try? await queueRef.child(candidate.key).removeValueAsync()
                    try? await queueRef.child(playerID).removeValueAsync()
                    return joined
                } catch {
                    // Candidate may have been claimed concurrently; keep searching.
                    continue
                }
            }
        }

        // No suitable opponent to join, so reuse own waiting match if still valid.
        if !ownEntryIsStale, let ownEntry,
           let ownMatchID = ownEntry["matchID"] as? String {
            if let existing = try await loadSharedMatch(matchID: ownMatchID) {
                if existing.playerIDs.contains(playerID), existing.playerIDs.count < 2, existing.winnerPlayerID == nil {
                    // Refresh heartbeat while waiting so own entry stays visible/fresh.
                    try? await queueRef.child(playerID).updateValueAsync([
                        "createdAtEpoch": now,
                        "profileName": profileName
                    ])
                    return existing
                }
            }
            try? await queueRef.child(playerID).removeValueAsync()
        }

        let puzzle = generator.generatePuzzle(difficulty: difficulty)
        let matchID = String(UUID().uuidString.prefix(6)).uppercased()
        let match = MatchState(
            matchID: matchID,
            puzzle: puzzle,
            playerIDs: [playerID],
            startedAtEpoch: nil,
            mode: .battle,
            winnerPlayerID: nil
        )

        let hostBoard = PlayerBoardState(
            playerID: playerID,
            values: puzzle.cells.map { $0.value },
            completion: CompletionState(),
            lives: 0,
            profileName: profileName,
            profileImageBase64: profileImageBase64,
            squaresLeft: puzzle.cells.filter { $0.value == nil }.count,
            mistakeCount: 0,
            lockRemainingSeconds: 0
        )

        try await matchesRef.child(matchID).child("shared").setValueAsync(try match.toDictionary())
        try await matchesRef.child(matchID).child("players").child(playerID).setValueAsync(try hostBoard.toDictionary())
        try await queueRef.child(playerID).setValueAsync([
            "matchID": matchID,
            "createdAtEpoch": now,
            "profileName": profileName
        ])

        return match
    }

    func leaveQueue(playerID: String) async {
        try? await queueRef.child(playerID).removeValueAsync()
    }

    private func joinExisting(
        matchID: String,
        playerID: String,
        profileName: String,
        profileImageBase64: String?
    ) async throws -> MatchState {
        guard var match = try await loadSharedMatch(matchID: matchID) else {
            throw NSError(domain: "ArenaQueue", code: 404, userInfo: [NSLocalizedDescriptionKey: "Arena match not found"])
        }

        if !match.playerIDs.contains(playerID), match.playerIDs.count >= 2 {
            throw NSError(domain: "ArenaQueue", code: 409, userInfo: [NSLocalizedDescriptionKey: "Arena match is already full"])
        }

        let wasWaitingForSecondPlayer = !match.playerIDs.contains(playerID) && match.playerIDs.count < 2
        if !match.playerIDs.contains(playerID) {
            match.playerIDs.append(playerID)
        }
        // Reset synchronized start gate/readiness when the second player is attached.
        // Countdown will start only after both clients report they are ready.
        if wasWaitingForSecondPlayer, match.playerIDs.count >= 2 {
            match.startedAtEpoch = nil
            match.readyPlayerIDs = []
            match.quitPlayerID = nil
            match.winnerPlayerID = nil
        }

        let board = PlayerBoardState(
            playerID: playerID,
            values: match.puzzle.cells.map { $0.value },
            completion: CompletionState(),
            lives: 0,
            profileName: profileName,
            profileImageBase64: profileImageBase64,
            squaresLeft: match.puzzle.cells.filter { $0.value == nil }.count,
            mistakeCount: 0,
            lockRemainingSeconds: 0
        )

        try await matchesRef.child(matchID).child("shared").setValueAsync(try match.toDictionary())
        try await matchesRef.child(matchID).child("players").child(playerID).setValueAsync(try board.toDictionary())
        return match
    }

    private func loadSharedMatch(matchID: String) async throws -> MatchState? {
        let sharedSnapshot = try await readValue(matchesRef.child(matchID).child("shared"))
        return try sharedSnapshot.decode(MatchState.self)
    }

    private func readValue(_ ref: DatabaseReference) async throws -> DataSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DataSnapshot, Error>) in
            ref.observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot)
            }
        }
    }

    private static func parseEpoch(_ raw: Any?) -> TimeInterval? {
        if let value = raw as? TimeInterval { return value }
        if let number = raw as? NSNumber { return number.doubleValue }
        if let string = raw as? String, let value = Double(string) { return value }
        return nil
    }
}

private extension DatabaseReference {
    func setValueAsync(_ value: Any) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setValue(value) { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func removeValueAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            removeValue { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func updateValueAsync(_ value: [AnyHashable: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            updateChildValues(value) { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private extension DataSnapshot {
    func decode<T: Decodable>(_ type: T.Type) throws -> T? {
        guard let value = value else { return nil }
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(type, from: data)
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
