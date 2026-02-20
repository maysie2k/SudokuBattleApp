import Foundation

struct PlayerBoardState: Codable {
    var playerID: String
    var values: [Int?]
    var completion: CompletionState
    var lives: Int
    var profileName: String? = nil
    var profileImageBase64: String? = nil
    var squaresLeft: Int? = nil
    var mistakeCount: Int? = nil
    var lockRemainingSeconds: Int? = nil
}

struct MatchState: Codable {
    var matchID: String
    var puzzle: SudokuPuzzle
    var playerIDs: [String]
    var startedAtEpoch: TimeInterval?
    var readyPlayerIDs: [String]? = nil
    var quitPlayerID: String? = nil
    var mode: GameMode? = nil
    var winnerPlayerID: String? = nil
}

enum MultiplayerEventType: String, Codable {
    case cellUpdate
    case completion
    case sabotage
    case emoji
    case punishment
    case powerClaim
    case powerSpawn
    case matchEnded
}

struct MultiplayerEvent: Codable, Identifiable {
    var id: String
    var type: MultiplayerEventType
    var sourcePlayerID: String
    var targetPlayerID: String?
    var payload: [String: String]
    var createdAtEpoch: TimeInterval
}
