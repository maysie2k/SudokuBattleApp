import Foundation

protocol MultiplayerServiceProtocol: AnyObject {
    var onMatchStateChange: ((MatchState) -> Void)? { get set }
    var onOpponentBoardChange: ((PlayerBoardState) -> Void)? { get set }
    var onEvent: ((MultiplayerEvent) -> Void)? { get set }

    func createMatch(puzzle: SudokuPuzzle, hostPlayerID: String, hostBoard: PlayerBoardState) async throws -> MatchState
    func joinMatch(matchID: String, playerID: String) async throws -> MatchState
    func observe(matchID: String, localPlayerID: String)
    func updateBoard(matchID: String, board: PlayerBoardState) async throws
    func sendEvent(matchID: String, event: MultiplayerEvent) async throws
    func updateShared(matchID: String, state: MatchState) async throws
    func stopObserving()
}

extension MultiplayerServiceProtocol {
    func updateBoard(matchID: String, board: PlayerBoardState) async throws {}
    func sendEvent(matchID: String, event: MultiplayerEvent) async throws {}
    func updateShared(matchID: String, state: MatchState) async throws {}
}
