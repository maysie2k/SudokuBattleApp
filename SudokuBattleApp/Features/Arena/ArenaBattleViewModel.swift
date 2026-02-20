import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class ArenaBattleViewModel: ObservableObject {
    @Published var isWaitingForOpponent = true
    @Published var isPreparingGame = false
    @Published var preparingCountdownValue: Int?
    @Published var isBoardRevealed = false
    @Published var board: [SudokuCell] = []
    @Published var selectedPosition: CellPosition?
    @Published var matchID = ""
    @Published var playerName = "Player 1"
    @Published var playerImage: UIImage?
    @Published var opponentName = "Player 2"
    @Published var opponentImage: UIImage?
    @Published var yourSquaresLeft = 0
    @Published var opponentSquaresLeft = 0
    @Published var opponentEmoji: String?
    @Published var sentEmoji: String?
    @Published var activePunishment: ArenaPunishmentState?
    @Published var punishmentLabel: String?
    @Published var isMoveBlocked = false
    @Published var hiddenRow: Int?
    @Published var hiddenColumn: Int?
    @Published var fadedDigit: Int?
    @Published var blackedBox: Int?
    @Published var highlightedRows: Set<Int> = []
    @Published var highlightedColumns: Set<Int> = []
    @Published var highlightedBoxes: Set<Int> = []
    @Published var completionPulseTrigger: Int = 0
    @Published var powerPushSegmentsFilled: Int = 0
    @Published var liveScore: Int = 0
    @Published var activePowerTile: CellPosition?
    @Published var powerTileSecondsLeft: Int = 0
    @Published var winnerText: String?
    @Published var outgoingPunishmentSecondsLeft: Int = 0
    @Published var outgoingPunishmentLabel: String?

    // Asset names expected in Assets.xcassets.
    let emojis = ["Emoji", "Emoji1", "Emoji2", "Emoji3", "Emoji4"]

    private let multiplayer: MultiplayerServiceProtocol
    private let matchmaker: ArenaMatchmakerServiceProtocol
    private let leaderboardService: ArenaLeaderboardServiceProtocol
    private let settingsStore: AppSettingsStore
    private let stableLeaderboardPlayerID: String
    private let playerID: String
    private let playerImageBase64: String?

    private var match: MatchState?
    private var powerTimer: Timer?
    private var punishmentTimer: Timer?
    private var outgoingPunishmentTimer: Timer?
    private var matchmakingRetryTask: Task<Void, Never>?
    private var startGateTimer: Timer?
    private var powerAttemptBlockedCycles: Set<Int> = []
    private var activePowerCycle: Int?
    private var powerTileCandidatePool: [CellPosition] = []
    private var opponentBoardValues: [Int?] = Array(repeating: nil, count: 81)
    private var completionState = CompletionState()
    private var completedDigits: Set<Int> = []
    private let completionFeedback = UINotificationFeedbackGenerator()
    private var punishmentBlocksInput = false
    private var hasOpponentBoardSnapshot = false
    private var pendingMatchedState: MatchState?
    private var didStartMatchPresentation = false
    private var lockedMatchID: String?
    private var localReadyAcknowledged = false
    private var arenaTimer: Timer?
    private var arenaElapsedSeconds: Int = 0
    private var totalErrorCount: Int = 0
    private var currentCorrectStreak: Int = 0
    private var maxCorrectStreak: Int = 0
    private var didSubmitArenaScore = false
    private let powerPushTarget = 10
    private let fxSound = FXSoundService.shared

    init(
        multiplayer: MultiplayerServiceProtocol = FirebaseRealtimeDatabaseService(),
        matchmaker: ArenaMatchmakerServiceProtocol = ArenaMatchmakerService(),
        leaderboardService: ArenaLeaderboardServiceProtocol = ArenaLeaderboardService(),
        settingsStore: AppSettingsStore = .shared
    ) {
        self.multiplayer = multiplayer
        self.matchmaker = matchmaker
        self.leaderboardService = leaderboardService
        self.settingsStore = settingsStore
        let stable = ArenaIdentity.stablePlayerID()
        self.stableLeaderboardPlayerID = stable
        self.playerID = ArenaIdentity.sessionPlayerID(baseStableID: stable)
        FirebaseServerClock.shared.start()
        let settings = settingsStore.load()
        self.playerName = settings.profileName
        self.playerImageBase64 = settings.profileImageData?.base64EncodedString()
        if let data = settings.profileImageData {
            self.playerImage = UIImage(data: data)
        }
        configureCallbacks()
    }

    func onAppear() {
        Task {
            await findMatch(fromRetry: false)
        }
    }

    var shouldConfirmQuitOnBack: Bool {
        winnerText == nil && isBoardRevealed
    }

    func onDisappear() {
        powerTimer?.invalidate()
        punishmentTimer?.invalidate()
        outgoingPunishmentTimer?.invalidate()
        arenaTimer?.invalidate()
        matchmakingRetryTask?.cancel()
        startGateTimer?.invalidate()
        multiplayer.stopObserving()
        lockedMatchID = nil
        localReadyAcknowledged = false
        Task { await matchmaker.leaveQueue(playerID: playerID) }
    }

    func selectCell(_ pos: CellPosition) {
        selectedPosition = pos
    }

    func sendEmoji(_ emoji: String) {
        guard let match else { return }
        let target = match.playerIDs.first(where: { $0 != playerID })
        let event = MultiplayerEvent(
            id: UUID().uuidString,
            type: .emoji,
            sourcePlayerID: playerID,
            targetPlayerID: target,
            payload: ["emoji": emoji],
            createdAtEpoch: Date().timeIntervalSince1970
        )
        Task { try? await multiplayer.sendEvent(matchID: match.matchID, event: event) }
        sentEmoji = emoji
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.sentEmoji = nil
        }
    }

    func place(_ number: Int) {
        guard !isWaitingForOpponent, !isPreparingGame, isBoardRevealed else { return }
        guard !isMoveBlocked, winnerText == nil else { return }
        guard let pos = selectedPosition else { return }
        let index = pos.row * 9 + pos.column
        guard board.indices.contains(index), !board[index].isGiven else { return }

        let values = board.map { $0.value }
        let legal = SudokuValidator.isPlacementLegal(number, at: pos, boardValues: values)
        let correct = board[index].solution == number
        guard legal && correct else {
            fxSound.playIncorrectPlacement()
            totalErrorCount += 1
            currentCorrectStreak = 0
            powerPushSegmentsFilled = 0
            updateLiveScore()
            return
        }

        board[index].value = number
        currentCorrectStreak += 1
        maxCorrectStreak = max(maxCorrectStreak, currentCorrectStreak)
        fxSound.playCorrectPlacement()
        let delta = evaluateCompletions(at: pos)
        let completedDigitNow = registerCompletedDigitIfNeeded(number)
        withAnimation(.easeInOut(duration: 0.25)) {
            highlightedRows.formUnion(delta.newRows)
            highlightedColumns.formUnion(delta.newColumns)
            highlightedBoxes.formUnion(delta.newBoxes)
        }
        if delta.hasAny || completedDigitNow {
            triggerCompletionFeedback()
        }

        yourSquaresLeft = board.filter { $0.value == nil }.count
        powerPushSegmentsFilled = min(powerPushTarget, powerPushSegmentsFilled + 1)
        syncBoard()

        if powerPushSegmentsFilled >= powerPushTarget {
            let punishment = ArenaPunishmentType.allCases.randomElement() ?? .pause
            applyPunishmentEventToOpponent(punishment)
            powerPushSegmentsFilled = 0
            fxSound.playPowerPushSuccess()
        }
        updateLiveScore()

        if board.allSatisfy({ $0.value == $0.solution }) {
            finishMatch(localPlayerWon: true)
            announceWinner()
        }
    }

    private func findMatch(fromRetry: Bool) async {
        // Keep retrying while waiting for opponent; stop retry only after pairing.
        if fromRetry, lockedMatchID != nil {
            return
        }

        do {
            let matched = try await matchmaker.enterQueue(
                playerID: playerID,
                profileName: playerName,
                profileImageBase64: playerImageBase64,
                difficulty: .hard
            )
            if let lockedMatchID, matched.matchID != lockedMatchID {
                return
            }
            self.match = matched
            self.matchID = matched.matchID
            self.board = matched.puzzle.cells
            self.powerTileCandidatePool = matched.puzzle.cells
                .filter { !$0.isGiven }
                .map(\.position)
            self.yourSquaresLeft = board.filter { $0.value == nil }.count
            self.opponentSquaresLeft = self.yourSquaresLeft
            self.hasOpponentBoardSnapshot = false
            self.pendingMatchedState = nil
            self.didStartMatchPresentation = false
            self.localReadyAcknowledged = false
            self.opponentName = "Player 2"
            self.opponentImage = nil
            self.outgoingPunishmentLabel = nil
            self.punishmentLabel = nil
            multiplayer.observe(matchID: matched.matchID, localPlayerID: playerID)
            syncBoard()
            if matched.playerIDs.count < 2 {
                isWaitingForOpponent = true
                if lockedMatchID == nil {
                    startMatchmakingRetryLoop()
                }
            } else {
                lockedMatchID = matched.matchID
                isWaitingForOpponent = true
                pendingMatchedState = matched
                maybePresentMatchedState()
                matchmakingRetryTask?.cancel()
            }
        } catch {
            isWaitingForOpponent = true
            if !fromRetry {
                startMatchmakingRetryLoop()
            }
        }
    }

    private func configureCallbacks() {
        multiplayer.onMatchStateChange = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                if let lockedMatchID = self.lockedMatchID, state.matchID != lockedMatchID {
                    return
                }
                self.match = state
                self.matchID = state.matchID
                if state.playerIDs.count < 2 {
                    if self.isPreparingGame || !self.isBoardRevealed {
                        self.resetToWaitingStateForRematch()
                    }
                } else {
                    if self.lockedMatchID == nil {
                        self.lockedMatchID = state.matchID
                    }
                    self.pendingMatchedState = state
                    self.maybePresentMatchedState()
                    self.matchmakingRetryTask?.cancel()
                }
                if let quitPlayerID = state.quitPlayerID {
                    self.handleMatchQuit(quitPlayerID: quitPlayerID)
                    return
                }
                if let winner = state.winnerPlayerID {
                    self.finishMatch(localPlayerWon: winner == self.playerID)
                    return
                }
                self.tryMarkLocalReady()
                self.tryArmCountdownIfAuthority()
            }
        }

        multiplayer.onOpponentBoardChange = { [weak self] boardState in
            DispatchQueue.main.async {
                self?.opponentName = boardState.profileName ?? "Player 2"
                self?.opponentSquaresLeft = boardState.squaresLeft ?? boardState.values.filter { $0 == nil }.count
                self?.opponentBoardValues = boardState.values
                if let base64 = boardState.profileImageBase64,
                   let data = Data(base64Encoded: base64),
                   let image = UIImage(data: data) {
                    self?.opponentImage = image
                }
                self?.hasOpponentBoardSnapshot = true
                self?.tryMarkLocalReady()
                self?.maybePresentMatchedState()
            }
        }

        multiplayer.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                guard let self else { return }
                switch event.type {
                case .emoji:
                    self.opponentEmoji = event.payload["emoji"]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        self.opponentEmoji = nil
                    }
                case .punishment:
                    if event.targetPlayerID == self.playerID,
                       let raw = event.payload["type"],
                       let type = ArenaPunishmentType(rawValue: raw) {
                        let endEpoch = Double(event.payload["endEpoch"] ?? "")
                        if type.duration > 0,
                           let endEpoch,
                           endEpoch <= FirebaseServerClock.shared.serverNowEpoch() {
                            return
                        }
                        self.applyPunishment(type, endEpoch: endEpoch)
                    }
                case .matchEnded:
                    if let quitPlayerID = event.payload["quitPlayerID"] {
                        self.handleMatchQuit(quitPlayerID: quitPlayerID)
                    } else if let winner = event.payload["winnerPlayerID"] {
                        self.finishMatch(localPlayerWon: winner == self.playerID)
                    }
                default:
                    break
                }
            }
        }
    }

    private func maybePresentMatchedState() {
        guard let state = pendingMatchedState, state.playerIDs.count >= 2 else { return }
        guard !didStartMatchPresentation else { return }
        guard state.startedAtEpoch != nil else {
            isWaitingForOpponent = true
            return
        }

        didStartMatchPresentation = true
        lockedMatchID = state.matchID
        isWaitingForOpponent = false
        configureStartGate(with: state)
    }

    private func applyPunishmentEventToOpponent(_ type: ArenaPunishmentType) {
        guard let match else { return }
        guard let target = match.playerIDs.first(where: { $0 != playerID }) else { return }
        let endEpoch = type.duration > 0
            ? FirebaseServerClock.shared.serverNowEpoch() + TimeInterval(type.duration)
            : nil

        var payload: [String: String] = ["type": type.rawValue]
        if let endEpoch {
            payload["endEpoch"] = String(endEpoch)
        }

        let event = MultiplayerEvent(
            id: UUID().uuidString,
            type: .punishment,
            sourcePlayerID: playerID,
            targetPlayerID: target,
            payload: payload,
            createdAtEpoch: Date().timeIntervalSince1970
        )
        Task { try? await multiplayer.sendEvent(matchID: match.matchID, event: event) }
        outgoingPunishmentLabel = nil
        outgoingPunishmentSecondsLeft = 0
    }

    private func applyPunishment(_ type: ArenaPunishmentType, endEpoch: TimeInterval?) {
        punishmentLabel = type.rawValue
        let initialRemaining: Int = {
            guard let endEpoch else { return type.duration }
            return max(0, Int(ceil(endEpoch - FirebaseServerClock.shared.serverNowEpoch())))
        }()
        activePunishment = ArenaPunishmentState(type: type, remainingSeconds: initialRemaining)
        hiddenRow = nil
        hiddenColumn = nil
        fadedDigit = nil
        blackedBox = nil

        switch type {
        case .pause:
            punishmentBlocksInput = true
            refreshMoveBlockState()
        case .whereDidYouGo:
            if Bool.random() { hiddenRow = Int.random(in: 0..<9) }
            else { hiddenColumn = Int.random(in: 0..<9) }
        case .byeBye:
            let candidates = board.indices.filter { !board[$0].isGiven && board[$0].value != nil }
            for idx in candidates.shuffled().prefix(5) { board[idx].value = nil }
            refreshCompletedDigits()
            yourSquaresLeft = board.filter { $0.value == nil }.count
            activePunishment = nil
            punishmentLabel = type.rawValue
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
                self?.punishmentLabel = nil
            }
            syncBoard()
            return
        case .fade:
            fadedDigit = Int.random(in: 1...9)
        case .youSquare:
            blackedBox = Int.random(in: 0..<9)
        }

        punishmentTimer?.invalidate()
        punishmentTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { return }
                guard var active = self.activePunishment else {
                    timer.invalidate(); return
                }
                if let endEpoch {
                    active.remainingSeconds = max(0, Int(ceil(endEpoch - FirebaseServerClock.shared.serverNowEpoch())))
                } else {
                    active.remainingSeconds -= 1
                }
                self.activePunishment = active
                if active.remainingSeconds <= 0 {
                    timer.invalidate()
                    self.activePunishment = nil
                    self.punishmentLabel = nil
                    self.hiddenRow = nil
                    self.hiddenColumn = nil
                    self.fadedDigit = nil
                    self.blackedBox = nil
                    self.punishmentBlocksInput = false
                    self.refreshMoveBlockState()
                }
            }
        }
    }

    private func announceWinner() {
        guard let match else { return }
        var updated = match
        updated.winnerPlayerID = playerID
        let finishEvent = MultiplayerEvent(
            id: UUID().uuidString,
            type: .matchEnded,
            sourcePlayerID: playerID,
            targetPlayerID: nil,
            payload: ["winnerPlayerID": playerID],
            createdAtEpoch: Date().timeIntervalSince1970
        )

        Task {
            try? await multiplayer.sendEvent(matchID: match.matchID, event: finishEvent)
            try? await multiplayer.updateShared(matchID: match.matchID, state: updated)
        }
    }

    func quitCurrentMatch() async {
        guard let match else {
            await matchmaker.leaveQueue(playerID: playerID)
            return
        }

        var updated = match
        updated.quitPlayerID = playerID
        updated.readyPlayerIDs = []
        updated.startedAtEpoch = nil

        let quitEvent = MultiplayerEvent(
            id: UUID().uuidString,
            type: .matchEnded,
            sourcePlayerID: playerID,
            targetPlayerID: nil,
            payload: ["quitPlayerID": playerID],
            createdAtEpoch: Date().timeIntervalSince1970
        )

        try? await multiplayer.sendEvent(matchID: match.matchID, event: quitEvent)
        try? await multiplayer.updateShared(matchID: match.matchID, state: updated)
        await matchmaker.leaveQueue(playerID: playerID)
    }

    func leaveFromBack() async {
        if shouldConfirmQuitOnBack {
            await quitCurrentMatch()
            return
        }
        // Waiting/pre-game exit should silently detach and return opponent to queue flow.
        if let match, !isBoardRevealed {
            var updated = match
            updated.playerIDs.removeAll(where: { $0 == playerID })
            updated.startedAtEpoch = nil
            updated.readyPlayerIDs = []
            updated.quitPlayerID = nil
            updated.winnerPlayerID = nil
            if updated.playerIDs.isEmpty {
                updated.playerIDs = []
            }
            try? await multiplayer.updateShared(matchID: match.matchID, state: updated)
        }
        await matchmaker.leaveQueue(playerID: playerID)
        multiplayer.stopObserving()
    }

    private func stopPowerTileCycle() {
        powerTimer?.invalidate()
        powerTileSecondsLeft = 0
        activePowerTile = nil
        activePowerCycle = nil
    }

    private func finishMatch(localPlayerWon: Bool) {
        winnerText = localPlayerWon ? "YOU WIN" : "YOU LOSE"
        stopPowerTileCycle()
        finalizeArenaScoreIfNeeded(didFinish: localPlayerWon)
    }

    private func handleMatchQuit(quitPlayerID: String) {
        guard quitPlayerID != playerID else { return }
        winnerText = "OPPONENT QUIT"
        stopPowerTileCycle()
    }

    private func resetToWaitingStateForRematch() {
        isWaitingForOpponent = true
        isPreparingGame = false
        preparingCountdownValue = nil
        isBoardRevealed = false
        pendingMatchedState = nil
        didStartMatchPresentation = false
        localReadyAcknowledged = false
        lockedMatchID = nil
        hasOpponentBoardSnapshot = false
        opponentName = "Player 2"
        opponentImage = nil
        startGateTimer?.invalidate()
        startMatchmakingRetryLoop()
    }

    private func syncBoard() {
        guard let match else { return }
        let payload = PlayerBoardState(
            playerID: playerID,
            values: board.map { $0.value },
            completion: completionState,
            lives: 0,
            profileName: playerName,
            // Keep board-sync payload lightweight; image is not needed per move.
            profileImageBase64: nil,
            squaresLeft: yourSquaresLeft,
            mistakeCount: nil,
            lockRemainingSeconds: nil
        )
        Task { try? await multiplayer.updateBoard(matchID: match.matchID, board: payload) }
    }

    private func refreshMoveBlockState() {
        isMoveBlocked = punishmentBlocksInput
    }

    private func evaluateCompletions(at position: CellPosition) -> BoardCompletionDelta {
        let values = board.map { $0.value }
        var delta = BoardCompletionDelta()

        if SudokuValidator.rowCompleted(position.row, boardValues: values),
           !completionState.completedRows.contains(position.row) {
            completionState.completedRows.insert(position.row)
            delta.newRows.insert(position.row)
        }

        if SudokuValidator.columnCompleted(position.column, boardValues: values),
           !completionState.completedColumns.contains(position.column) {
            completionState.completedColumns.insert(position.column)
            delta.newColumns.insert(position.column)
        }

        let box = position.boxIndex
        if SudokuValidator.boxCompleted(box, boardValues: values),
           !completionState.completedBoxes.contains(box) {
            completionState.completedBoxes.insert(box)
            delta.newBoxes.insert(box)
        }

        return delta
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

    private func triggerCompletionFeedback() {
        completionPulseTrigger += 1
        guard settingsStore.load().hapticsEnabled else { return }
        completionFeedback.notificationOccurred(.success)
        completionFeedback.prepare()
    }

    private func startMatchmakingRetryLoop() {
        guard lockedMatchID == nil else { return }
        matchmakingRetryTask?.cancel()
        matchmakingRetryTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { return }
                if !self.isWaitingForOpponent { return }
                if self.lockedMatchID != nil { return }
                await self.findMatch(fromRetry: true)
            }
        }
    }

    private func configureStartGate(with state: MatchState) {
        guard state.playerIDs.count >= 2 else { return }
        guard let startEpoch = state.startedAtEpoch else {
            revealBoardNow()
            return
        }

        let now = FirebaseServerClock.shared.serverNowEpoch()
        let initialRemaining = max(0, Int(ceil(startEpoch - now)))
        if initialRemaining <= 0 {
            revealBoardNow()
            return
        }

        isPreparingGame = true
        isBoardRevealed = false
        preparingCountdownValue = initialRemaining
        startGateTimer?.invalidate()
        startGateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                let remaining = max(0, Int(ceil(startEpoch - FirebaseServerClock.shared.serverNowEpoch())))
                self.preparingCountdownValue = remaining
                if remaining <= 0 {
                    timer.invalidate()
                    self.revealBoardNow()
                }
            }
        }
    }

    private func readyToStartPrerequisitesMet() -> Bool {
        guard let match else { return false }
        guard match.playerIDs.count >= 2 else { return false }
        let hasOpponentName = !opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Do not block match start on avatar image availability.
        // Some players may not set a profile image, and image decode can arrive later.
        return hasOpponentBoardSnapshot && hasOpponentName
    }

    private func tryMarkLocalReady() {
        guard readyToStartPrerequisitesMet() else { return }
        guard var match else { return }

        var ready = Set(match.readyPlayerIDs ?? [])
        guard !ready.contains(playerID) else {
            localReadyAcknowledged = true
            return
        }

        ready.insert(playerID)
        match.readyPlayerIDs = Array(ready).sorted()
        self.match = match
        localReadyAcknowledged = true

        Task { try? await multiplayer.updateShared(matchID: match.matchID, state: match) }
    }

    private func tryArmCountdownIfAuthority() {
        guard var match else { return }
        guard match.playerIDs.count >= 2 else { return }
        guard match.startedAtEpoch == nil else { return }

        let ready = Set(match.readyPlayerIDs ?? [])
        let allPlayers = Set(match.playerIDs)
        guard allPlayers.isSubset(of: ready) else { return }

        let authority = match.playerIDs.sorted().first
        guard authority == playerID else { return }

        // Small buffer after both-ready ack to show synchronized countdown start.
        match.startedAtEpoch = FirebaseServerClock.shared.serverNowEpoch() + 5.0
        self.match = match
        pendingMatchedState = match
        maybePresentMatchedState()
        Task { try? await multiplayer.updateShared(matchID: match.matchID, state: match) }
    }

    private func revealBoardNow() {
        isPreparingGame = false
        isBoardRevealed = true
        preparingCountdownValue = nil
        startGateTimer?.invalidate()
        completionState = CompletionState()
        highlightedRows.removeAll()
        highlightedColumns.removeAll()
        highlightedBoxes.removeAll()
        completedDigits = Self.completedDigits(from: board)
        outgoingPunishmentLabel = nil
        punishmentLabel = nil
        punishmentBlocksInput = false
        refreshMoveBlockState()
        arenaElapsedSeconds = 0
        totalErrorCount = 0
        currentCorrectStreak = 0
        maxCorrectStreak = 0
        powerPushSegmentsFilled = 0
        liveScore = 0
        didSubmitArenaScore = false
        powerTileCandidatePool = board.filter { !$0.isGiven }.map(\.position)
        startArenaClock()
        if settingsStore.load().hapticsEnabled {
            completionFeedback.prepare()
        }
        syncBoard()
        stopPowerTileCycle()
    }

    private func startArenaClock() {
        arenaTimer?.invalidate()
        arenaTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.arenaElapsedSeconds += 1
                self?.updateLiveScore()
            }
        }
    }

    private func updateLiveScore() {
        let completedSquares = board.compactMap(\.value).count
        let completionRatio = min(1.0, max(0.0, Double(completedSquares) / 81.0))
        let elapsed = Double(max(arenaElapsedSeconds, 1))
        let denominator = Double(max(completedSquares, 1))
        let scoringTime = max(1.0, (elapsed / denominator) * 81.0)

        let score =
            (completionRatio * 1000.0) +
            (10000.0 / scoringTime) -
            (Double(totalErrorCount) * 5.0) +
            (Double(maxCorrectStreak) * 2.0)
        liveScore = max(0, Int(score.rounded()))
    }

    private func finalizeArenaScoreIfNeeded(didFinish: Bool) {
        guard !didSubmitArenaScore else { return }
        guard let match else { return }
        didSubmitArenaScore = true
        arenaTimer?.invalidate()

        let completedSquares = board.compactMap(\.value).count
        let completionRatio = min(1.0, max(0.0, Double(completedSquares) / 81.0))
        let elapsed = Double(max(arenaElapsedSeconds, 1))
        let scoringTime: Double
        if didFinish {
            scoringTime = elapsed
        } else {
            let denominator = Double(max(completedSquares, 1))
            scoringTime = max(1.0, (elapsed / denominator) * 81.0)
        }

        let score =
            (completionRatio * 1000.0) +
            (10000.0 / scoringTime) -
            (Double(totalErrorCount) * 5.0) +
            (Double(maxCorrectStreak) * 2.0)

        let now = Date().timeIntervalSince1970
        let monthKey = ArenaLeaderboardMonth.currentKey()
        let result = ArenaMatchResult(
            playerID: stableLeaderboardPlayerID,
            displayName: playerName,
            matchID: match.matchID,
            monthKey: monthKey,
            completedSquares: completedSquares,
            completionRatio: completionRatio,
            elapsedSeconds: elapsed,
            scoringTimeSeconds: scoringTime,
            didFinish: didFinish,
            errors: totalErrorCount,
            maxStreak: maxCorrectStreak,
            score: score,
            createdAtEpoch: now
        )

        Task {
            try? await leaderboardService.recordMatchResult(result, minMatches: 2)
        }
    }

    private static func stableHash(_ value: String) -> Int {
        var hash = 5381
        for byte in value.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return abs(hash)
    }
}
