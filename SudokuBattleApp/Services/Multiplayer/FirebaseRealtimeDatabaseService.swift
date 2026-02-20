import Foundation
import FirebaseDatabase
import FirebaseCore

final class FirebaseRealtimeDatabaseService: MultiplayerServiceProtocol {
    private let rootRef: DatabaseReference
    private var handles: [DatabaseHandle] = []
    private var observingMatchID: String?
    private var localPlayerID: String?

    var onMatchStateChange: ((MatchState) -> Void)?
    var onOpponentBoardChange: ((PlayerBoardState) -> Void)?
    var onEvent: ((MultiplayerEvent) -> Void)?

    init() {
        let options = FirebaseApp.app()?.options
        if let configuredURL = options?.databaseURL, !configuredURL.isEmpty {
            rootRef = Database.database(url: configuredURL).reference().child("matches")
        } else if let projectID = options?.projectID, !projectID.isEmpty {
            let fallbackURL = "https://\(projectID)-default-rtdb.firebaseio.com"
            rootRef = Database.database(url: fallbackURL).reference().child("matches")
        } else {
            rootRef = Database.database().reference().child("matches")
        }
    }

    func createMatch(puzzle: SudokuPuzzle, hostPlayerID: String, hostBoard: PlayerBoardState) async throws -> MatchState {
        let matchID = String(UUID().uuidString.prefix(6)).uppercased()
        let match = MatchState(
            matchID: matchID,
            puzzle: puzzle,
            playerIDs: [hostPlayerID],
            startedAtEpoch: nil,
            mode: .battle,
            winnerPlayerID: nil
        )

        let matchRef = rootRef.child(matchID)
        try await setValue(matchRef.child("shared"), value: try match.toDictionary())
        try await setValue(matchRef.child("players").child(hostPlayerID), value: try hostBoard.toDictionary())

        return match
    }

    func joinMatch(matchID: String, playerID: String) async throws -> MatchState {
        let matchRef = rootRef.child(matchID)
        let snapshot = try await readValue(matchRef.child("shared"))
        guard var match = try snapshot.decode(MatchState.self) else {
            throw NSError(domain: "Multiplayer", code: 404, userInfo: [NSLocalizedDescriptionKey: "Match not found"])
        }

        if !match.playerIDs.contains(playerID) {
            match.playerIDs.append(playerID)
        }

        try await setValue(matchRef.child("shared"), value: try match.toDictionary())
        let board = initialBoardState(from: match.puzzle, playerID: playerID)
        try await setValue(matchRef.child("players").child(playerID), value: try board.toDictionary())
        return match
    }

    func observe(matchID: String, localPlayerID: String) {
        stopObserving()

        self.observingMatchID = matchID
        self.localPlayerID = localPlayerID

        let sharedRef = rootRef.child(matchID).child("shared")
        let playersRef = rootRef.child(matchID).child("players")
        let eventsRef = rootRef.child(matchID).child("events")

        let sharedHandle = sharedRef.observe(.value) { [weak self] snapshot in
            guard let state = try? snapshot.decode(MatchState.self) else { return }
            self?.onMatchStateChange?(state)
        }

        let playersHandle = playersRef.observe(.value) { [weak self] snapshot in
            guard
                let self,
                let all = snapshot.value as? [String: Any]
            else { return }

            for (playerID, value) in all where playerID != localPlayerID {
                guard let payload = value as? [String: Any] else { continue }
                if let boardState = Self.parsePlayerBoardState(playerID: playerID, payload: payload) {
                    self.onOpponentBoardChange?(boardState)
                }
            }
        }

        let eventsHandle = eventsRef.observe(.childAdded) { [weak self] snapshot in
            guard
                let self,
                let payload = snapshot.value as? [String: Any],
                let event = Self.parseMultiplayerEvent(id: snapshot.key, payload: payload),
                event.sourcePlayerID != localPlayerID
            else { return }
            self.onEvent?(event)
        }

        handles = [sharedHandle, playersHandle, eventsHandle]
    }

    func updateBoard(matchID: String, board: PlayerBoardState) async throws {
        try await updateValues(
            rootRef.child(matchID).child("players").child(board.playerID),
            values: try board.toDictionary()
        )
    }

    func sendEvent(matchID: String, event: MultiplayerEvent) async throws {
        try await setValue(
            rootRef.child(matchID).child("events").child(event.id),
            value: try event.toDictionary()
        )
    }

    func updateShared(matchID: String, state: MatchState) async throws {
        try await setValue(
            rootRef.child(matchID).child("shared"),
            value: try state.toDictionary()
        )
    }

    func stopObserving() {
        guard let matchID = observingMatchID else { return }
        rootRef.child(matchID).removeAllObservers()
        rootRef.child(matchID).child("shared").removeAllObservers()
        rootRef.child(matchID).child("players").removeAllObservers()
        rootRef.child(matchID).child("events").removeAllObservers()
        handles.removeAll()
        observingMatchID = nil
        localPlayerID = nil
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

    private func updateValues(_ ref: DatabaseReference, values: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateChildValues(values) { error, _ in
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

    private func initialBoardState(from puzzle: SudokuPuzzle, playerID: String) -> PlayerBoardState {
        // Each player starts from the same givens, but tracks independent progress.
        PlayerBoardState(
            playerID: playerID,
            values: puzzle.cells.map { $0.value },
            completion: CompletionState(),
            lives: 5,
            profileName: nil,
            profileImageBase64: nil
        )
    }

    private static func parsePlayerBoardState(playerID: String, payload: [String: Any]) -> PlayerBoardState? {
        let values = parseOptionalIntArray(payload["values"])

        let completionPayload = payload["completion"] as? [String: Any] ?? [:]
        let completion = CompletionState(
            completedRows: parseIntSet(completionPayload["completedRows"]),
            completedColumns: parseIntSet(completionPayload["completedColumns"]),
            completedBoxes: parseIntSet(completionPayload["completedBoxes"])
        )

        let lives: Int
        if let intLives = payload["lives"] as? Int {
            lives = intLives
        } else if let numLives = payload["lives"] as? NSNumber {
            lives = numLives.intValue
        } else {
            lives = 0
        }

        let normalizedValues: [Int?] = {
            if values.count == 81 { return values }
            if values.count > 81 { return Array(values.prefix(81)) }
            return values + Array(repeating: nil, count: 81 - values.count)
        }()

        return PlayerBoardState(
            playerID: playerID,
            values: normalizedValues,
            completion: completion,
            lives: lives,
            profileName: payload["profileName"] as? String,
            profileImageBase64: payload["profileImageBase64"] as? String,
            squaresLeft: parseOptionalInt(payload["squaresLeft"]),
            mistakeCount: parseOptionalInt(payload["mistakeCount"]),
            lockRemainingSeconds: parseOptionalInt(payload["lockRemainingSeconds"])
        )
    }

    private static func parseOptionalIntArray(_ raw: Any?) -> [Int?] {
        if let array = raw as? [Any] {
            return array.map(parseOptionalInt)
        }

        // Realtime Database may return arrays as index-keyed dictionaries.
        if let keyed = raw as? [String: Any] {
            let ordered = keyed
                .compactMap { key, value -> (Int, Any)? in
                    guard let index = Int(key) else { return nil }
                    return (index, value)
                }
                .sorted(by: { $0.0 < $1.0 })
                .map(\.1)
            return ordered.map(parseOptionalInt)
        }

        return []
    }

    private static func parseOptionalInt(_ raw: Any?) -> Int? {
        guard let raw else { return nil }
        if raw is NSNull { return nil }
        if let intVal = raw as? Int { return intVal }
        if let num = raw as? NSNumber { return num.intValue }
        return nil
    }

    private static func parseMultiplayerEvent(id: String, payload: [String: Any]) -> MultiplayerEvent? {
        guard
            let typeRaw = payload["type"] as? String,
            let type = MultiplayerEventType(rawValue: typeRaw),
            let sourcePlayerID = payload["sourcePlayerID"] as? String
        else { return nil }

        let createdAt: TimeInterval
        if let value = payload["createdAtEpoch"] as? TimeInterval {
            createdAt = value
        } else if let num = payload["createdAtEpoch"] as? NSNumber {
            createdAt = num.doubleValue
        } else {
            createdAt = Date().timeIntervalSince1970
        }

        return MultiplayerEvent(
            id: id,
            type: type,
            sourcePlayerID: sourcePlayerID,
            targetPlayerID: payload["targetPlayerID"] as? String,
            payload: parseStringDictionary(payload["payload"]),
            createdAtEpoch: createdAt
        )
    }

    private static func parseIntSet(_ raw: Any?) -> Set<Int> {
        guard let raw else { return [] }
        if let ints = raw as? [Int] { return Set(ints) }
        if let nums = raw as? [NSNumber] { return Set(nums.map(\.intValue)) }
        return []
    }

    private static func parseStringDictionary(_ raw: Any?) -> [String: String] {
        guard let dict = raw as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in dict {
            if let string = value as? String {
                result[key] = string
            } else if let number = value as? NSNumber {
                result[key] = number.stringValue
            }
        }
        return result
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
