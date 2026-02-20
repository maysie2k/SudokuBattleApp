import Foundation
import SwiftUI
import UIKit

import Combine

enum GlowTheme {
    case angel
    case attackGreen
    case damageRed
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published var phase: GamePhase = .difficultySelection
    @Published var difficulty: SudokuDifficulty?
    @Published var board: [SudokuCell] = []
    @Published var selectedPosition: CellPosition?
    @Published var lives: Int = 5
    @Published var elapsedSeconds: Int = 0
    @Published var timerText: String = "00:00"
    @Published var completionState = CompletionState()
    @Published var opponentCompletion = CompletionState()
    @Published var highlightedRows: Set<Int> = []
    @Published var highlightedColumns: Set<Int> = []
    @Published var highlightedBoxes: Set<Int> = []
    @Published var sabotageFlash = false
    @Published var opponentProgress: Double = 0
    @Published var matchCode: String = ""
    @Published var bannerText: String?
    @Published var completionPulseTrigger: Int = 0
    @Published var glowTheme: GlowTheme = .angel
    @Published var soloCountdownValue: Int?
    @Published var soloBestTimeText: String = "--:--"

    let mode: GameMode
    let playerID: String

    private var timer: Timer?
    private let generator = SudokuGenerator()
    private let multiplayerService: MultiplayerServiceProtocol
    private let boosterService: BoosterServiceProtocol
    private let settingsStore: AppSettingsStore
    private let completionFeedback = UINotificationFeedbackGenerator()
    private var currentPuzzle: SudokuPuzzle?
    private var currentMatch: MatchState?
    private var completedDigits: Set<Int> = []
    private var soloCountdownTask: Task<Void, Never>?
    private let fxSound = FXSoundService.shared

    init(
        mode: GameMode,
        playerID: String = String(UUID().uuidString.prefix(8)),
        multiplayerService: MultiplayerServiceProtocol = FirebaseRealtimeDatabaseService(),
        boosterService: BoosterServiceProtocol = PlaceholderBoosterService(),
        settingsStore: AppSettingsStore = .shared
    ) {
        self.mode = mode
        self.playerID = playerID
        self.multiplayerService = multiplayerService
        self.boosterService = boosterService
        self.settingsStore = settingsStore
        configureMultiplayerCallbacks()
    }

    func selectDifficulty(_ difficulty: SudokuDifficulty) {
        self.difficulty = difficulty
        let puzzle = generator.generatePuzzle(difficulty: difficulty)
        configurePuzzle(puzzle)
        updateSoloBestTimeText()
        phase = .ready
    }

    func goTapped() {
        soloCountdownTask?.cancel()
        soloCountdownTask = nil
        soloCountdownValue = nil
        phase = .playing
        if settingsStore.load().hapticsEnabled {
            completionFeedback.prepare()
        }
        startTimer()
    }

    func resetToDifficultySelection() {
        stopTimer()
        difficulty = nil
        currentPuzzle = nil
        currentMatch = nil
        board = []
        lives = 5
        elapsedSeconds = 0
        timerText = "00:00"
        completionState = CompletionState()
        opponentCompletion = CompletionState()
        highlightedRows.removeAll()
        highlightedColumns.removeAll()
        highlightedBoxes.removeAll()
        opponentProgress = 0
        matchCode = ""
        bannerText = nil
        soloCountdownTask?.cancel()
        soloCountdownTask = nil
        soloCountdownValue = nil
        soloBestTimeText = "--:--"
        phase = .difficultySelection
        multiplayerService.stopObserving()
    }

    func createMatch() {
        guard mode == .battle, let puzzle = currentPuzzle else { return }
        Task {
            let boardState = localBoardState()
            do {
                let match = try await multiplayerService.createMatch(
                    puzzle: puzzle,
                    hostPlayerID: playerID,
                    hostBoard: boardState
                )
                currentMatch = match
                matchCode = match.matchID
                multiplayerService.observe(matchID: match.matchID, localPlayerID: playerID)
                bannerText = "Match code: \(match.matchID)"
            } catch {
                bannerText = error.localizedDescription
            }
        }
    }

    func joinMatch(code: String) {
        guard mode == .battle else { return }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return }

        Task {
            do {
                let joined = try await multiplayerService.joinMatch(
                    matchID: normalized,
                    playerID: playerID
                )
                currentMatch = joined
                matchCode = joined.matchID
                configurePuzzle(joined.puzzle)
                phase = .ready
                multiplayerService.observe(matchID: joined.matchID, localPlayerID: playerID)
                bannerText = "Joined \(joined.matchID)"
            } catch {
                bannerText = "Join failed: \(error.localizedDescription)"
            }
        }
    }

    func selectCell(_ position: CellPosition) {
        selectedPosition = position
    }

    func placeNumber(_ number: Int) {
        guard phase == .playing, let position = selectedPosition else { return }
        let index = position.row * 9 + position.column
        guard board.indices.contains(index), !board[index].isGiven else { return }

        let values = board.map { $0.value }
        let legal = SudokuValidator.isPlacementLegal(number, at: position, boardValues: values)
        let correct = board[index].solution == number

        guard legal && correct else {
            loseLife()
            return
        }

        board[index].value = number
        fxSound.playCorrectPlacement()
        let delta = evaluateCompletions(at: position)
        let completedDigitNow = registerCompletedDigitIfNeeded(number)
        withAnimation(.easeInOut(duration: 0.25)) {
            highlightedRows.formUnion(delta.newRows)
            highlightedColumns.formUnion(delta.newColumns)
            highlightedBoxes.formUnion(delta.newBoxes)
        }

        if delta.hasAny || completedDigitNow {
            triggerCompletionFeedback(theme: .angel, haptic: .success)
        }

        if mode == .battle {
            syncBoard()
            sendCompletionEvent(delta)
            maybeSabotageOpponent(for: delta)
        }

        checkForCompletion()
    }

    func clearSelectedCell() {
        guard phase == .playing, let position = selectedPosition else { return }
        let index = position.row * 9 + position.column
        guard board.indices.contains(index), !board[index].isGiven else { return }
        board[index].value = nil
        refreshCompletedDigits()
        if mode == .battle { syncBoard() }
    }

    private func configurePuzzle(_ puzzle: SudokuPuzzle) {
        currentPuzzle = puzzle
        board = puzzle.cells
        lives = 5
        elapsedSeconds = 0
        timerText = "00:00"
        completionState = CompletionState()
        opponentCompletion = CompletionState()
        highlightedRows = []
        highlightedColumns = []
        highlightedBoxes = []
        opponentProgress = 0
        selectedPosition = nil
        bannerText = nil
        completedDigits = Self.completedDigits(from: board)
    }

    private func evaluateCompletions(at position: CellPosition) -> BoardCompletionDelta {
        let values = board.map { $0.value }
        var delta = BoardCompletionDelta()

        if SudokuValidator.rowCompleted(position.row, boardValues: values), !completionState.completedRows.contains(position.row) {
            completionState.completedRows.insert(position.row)
            delta.newRows.insert(position.row)
        }

        if SudokuValidator.columnCompleted(position.column, boardValues: values), !completionState.completedColumns.contains(position.column) {
            completionState.completedColumns.insert(position.column)
            delta.newColumns.insert(position.column)
        }

        let box = position.boxIndex
        if SudokuValidator.boxCompleted(box, boardValues: values), !completionState.completedBoxes.contains(box) {
            completionState.completedBoxes.insert(box)
            delta.newBoxes.insert(box)
        }

        return delta
    }

    private func checkForCompletion() {
        if board.allSatisfy({ $0.value == $0.solution }) {
            if mode == .solo {
                updateSoloLeaderboardIfNeeded()
            }
            phase = .complete
            stopTimer()
        }
    }

    private func loseLife() {
        lives -= 1
        fxSound.playIncorrectPlacement()
        triggerCompletionFeedback(theme: .damageRed, haptic: .error)
        if lives <= 0 {
            lives = 0
            phase = .gameOver
            stopTimer()
        }

        if mode == .battle {
            syncBoard()
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds += 1
                self.timerText = Self.formatTime(self.elapsedSeconds)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func localBoardState() -> PlayerBoardState {
        PlayerBoardState(
            playerID: playerID,
            values: board.map { $0.value },
            completion: completionState,
            lives: lives
        )
    }

    private func syncBoard() {
        guard let match = currentMatch else { return }
        let state = localBoardState()
        Task {
            try? await multiplayerService.updateBoard(matchID: match.matchID, board: state)
        }
    }

    private func sendCompletionEvent(_ delta: BoardCompletionDelta) {
        guard delta.hasAny, let match = currentMatch else { return }
        let payload: [String: String] = [
            "rows": delta.newRows.map(String.init).joined(separator: ","),
            "columns": delta.newColumns.map(String.init).joined(separator: ","),
            "boxes": delta.newBoxes.map(String.init).joined(separator: ",")
        ]

        let event = MultiplayerEvent(
            id: UUID().uuidString,
            type: .completion,
            sourcePlayerID: playerID,
            targetPlayerID: nil,
            payload: payload,
            createdAtEpoch: Date().timeIntervalSince1970
        )

        Task {
            try? await multiplayerService.sendEvent(matchID: match.matchID, event: event)
        }
    }

    private func maybeSabotageOpponent(for delta: BoardCompletionDelta) {
        // Sabotage is optional by design and only triggers after a fresh completion.
        guard delta.hasAny, Bool.random(), let match = currentMatch else { return }
        guard let target = match.playerIDs.first(where: { $0 != playerID }) else { return }

        let removedCount = Int.random(in: 1...3)
        let event = MultiplayerEvent(
            id: UUID().uuidString,
            type: .sabotage,
            sourcePlayerID: playerID,
            targetPlayerID: target,
            payload: ["removeCount": String(removedCount)],
            createdAtEpoch: Date().timeIntervalSince1970
        )

        Task {
            try? await multiplayerService.sendEvent(matchID: match.matchID, event: event)
        }

        triggerCompletionFeedback(theme: .attackGreen, haptic: .success)
    }

    private func applySabotage(removeCount: Int) {
        let candidates = board.indices.filter {
            !board[$0].isGiven && board[$0].value == board[$0].solution
        }

        guard !candidates.isEmpty else { return }

        for index in candidates.shuffled().prefix(removeCount) {
            board[index].value = nil
        }
        refreshCompletedDigits()

        withAnimation(.easeInOut(duration: 0.3)) {
            sabotageFlash = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.sabotageFlash = false
            }
        }
    }

    private func configureMultiplayerCallbacks() {
        multiplayerService.onMatchStateChange = { [weak self] match in
            DispatchQueue.main.async {
                guard let self else { return }
                self.currentMatch = match
                self.matchCode = match.matchID
                if self.currentPuzzle?.id != match.puzzle.id {
                    self.configurePuzzle(match.puzzle)
                    self.phase = .ready
                }
            }
        }

        multiplayerService.onOpponentBoardChange = { [weak self] opponentBoard in
            DispatchQueue.main.async {
                guard let self else { return }
                self.opponentCompletion = opponentBoard.completion
                let solvedCount = opponentBoard.values.compactMap { $0 }.count
                self.opponentProgress = Double(solvedCount) / 81.0
            }
        }

        multiplayerService.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                guard let self else { return }

                switch event.type {
                case .completion:
                    self.mergeCompletionHighlights(from: event.payload)
                case .sabotage:
                    if event.targetPlayerID == self.playerID,
                       let remove = Int(event.payload["removeCount"] ?? "1") {
                        self.applySabotage(removeCount: remove)
                        self.triggerCompletionFeedback(theme: .damageRed, haptic: .error)
                    }
                case .cellUpdate:
                    break
                case .emoji:
                    break
                case .punishment:
                    break
                case .powerClaim:
                    break
                case .powerSpawn:
                    break
                case .matchEnded:
                    break
                }
            }
        }
    }

    private func mergeCompletionHighlights(from payload: [String: String]) {
        let rows = parseIndexes(payload["rows"])
        let columns = parseIndexes(payload["columns"])
        let boxes = parseIndexes(payload["boxes"])

        opponentCompletion.completedRows.formUnion(rows)
        opponentCompletion.completedColumns.formUnion(columns)
        opponentCompletion.completedBoxes.formUnion(boxes)

        withAnimation(.easeInOut(duration: 0.3)) {
            highlightedRows.formUnion(rows)
            highlightedColumns.formUnion(columns)
            highlightedBoxes.formUnion(boxes)
        }
    }

    private func parseIndexes(_ csv: String?) -> Set<Int> {
        guard let csv, !csv.isEmpty else { return [] }
        return Set(csv.split(separator: ",").compactMap { Int($0) })
    }

    private func registerCompletedDigitIfNeeded(_ digit: Int) -> Bool {
        let count = board.compactMap(\.value).filter { $0 == digit }.count
        guard count >= 9, !completedDigits.contains(digit) else { return false }
        completedDigits.insert(digit)
        return true
    }

    private func refreshCompletedDigits() {
        completedDigits = Self.completedDigits(from: board)
    }

    private static func completedDigits(from board: [SudokuCell]) -> Set<Int> {
        var counts: [Int: Int] = [:]
        for value in board.compactMap(\.value) {
            counts[value, default: 0] += 1
        }
        return Set((1...9).filter { counts[$0, default: 0] >= 9 })
    }

    private func triggerCompletionFeedback(theme: GlowTheme, haptic: UINotificationFeedbackGenerator.FeedbackType) {
        glowTheme = theme
        completionPulseTrigger += 1
        guard settingsStore.load().hapticsEnabled else { return }
        completionFeedback.notificationOccurred(haptic)
        completionFeedback.prepare()
    }

    func startSoloCountdownIfNeeded() {
        guard mode == .solo, phase == .ready else { return }
        guard soloCountdownTask == nil else { return }
        soloCountdownTask?.cancel()
        soloCountdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 220_000_000)
            for value in stride(from: 5, through: 1, by: -1) {
                if Task.isCancelled { return }
                self.soloCountdownValue = value
                if value > 1 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                } else {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }

            if Task.isCancelled { return }
            self.soloCountdownValue = nil
            self.goTapped()
        }
    }

    private func updateSoloLeaderboardIfNeeded() {
        var settings = settingsStore.load()
        guard let difficulty else { return }

        let entry = SoloLeaderboardEntry(
            id: UUID().uuidString,
            difficultyRawValue: difficulty.rawValue,
            timeSeconds: elapsedSeconds,
            livesLeft: lives,
            createdAtEpoch: Date().timeIntervalSince1970
        )

        settings.soloLeaderboard.append(entry)
        settings.soloLeaderboard.sort {
            if $0.timeSeconds == $1.timeSeconds {
                if $0.livesLeft == $1.livesLeft {
                    return $0.createdAtEpoch < $1.createdAtEpoch
                }
                return $0.livesLeft > $1.livesLeft
            }
            return $0.timeSeconds < $1.timeSeconds
        }
        settings.soloLeaderboard = Array(settings.soloLeaderboard.prefix(5))
        settingsStore.save(settings)
        updateSoloBestTimeText()
    }

    private func updateSoloBestTimeText() {
        guard let difficulty else {
            soloBestTimeText = "--:--"
            return
        }
        let settings = settingsStore.load()
        let best = settings.soloLeaderboard
            .filter { $0.difficultyRawValue == difficulty.rawValue }
            .min { lhs, rhs in
                if lhs.timeSeconds == rhs.timeSeconds {
                    return lhs.createdAtEpoch < rhs.createdAtEpoch
                }
                return lhs.timeSeconds < rhs.timeSeconds
            }
        if let best {
            soloBestTimeText = Self.formatTime(best.timeSeconds)
        } else {
            soloBestTimeText = "--:--"
        }
    }

    private static func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
