import Foundation

struct SudokuGenerator {
    func generatePuzzle(difficulty: SudokuDifficulty) -> SudokuPuzzle {
        var solvedBoard = Array(repeating: 0, count: 81)
        _ = fillBoard(&solvedBoard)

        var puzzleBoard = solvedBoard
        removeCells(from: &puzzleBoard, toReach: difficulty.emptyCells)

        let cells = (0..<81).map { index -> SudokuCell in
            let row = index / 9
            let column = index % 9
            let value = puzzleBoard[index] == 0 ? nil : puzzleBoard[index]
            return SudokuCell(
                row: row,
                column: column,
                solution: solvedBoard[index],
                isGiven: value != nil,
                value: value
            )
        }

        return SudokuPuzzle(
            id: UUID().uuidString,
            difficulty: difficulty,
            cells: cells
        )
    }

    private func fillBoard(_ board: inout [Int], index: Int = 0) -> Bool {
        if index >= 81 { return true }

        if board[index] != 0 {
            return fillBoard(&board, index: index + 1)
        }

        let numbers = Array(1...9).shuffled()
        let row = index / 9
        let column = index % 9

        for number in numbers {
            if canPlace(number, row: row, column: column, board: board) {
                board[index] = number
                if fillBoard(&board, index: index + 1) {
                    return true
                }
                board[index] = 0
            }
        }

        return false
    }

    private func removeCells(from board: inout [Int], toReach emptyTarget: Int) {
        var indexes = Array(0..<81).shuffled()
        var removed = 0

        while removed < emptyTarget, let index = indexes.popLast() {
            let backup = board[index]
            board[index] = 0

            // Keep only removals that preserve a unique solution.
            if solutionCount(for: board, limit: 2) != 1 {
                board[index] = backup
                continue
            }

            removed += 1
        }
    }

    private func solutionCount(for board: [Int], limit: Int) -> Int {
        var mutable = board
        return solveCount(&mutable, limit: limit)
    }

    private func solveCount(_ board: inout [Int], limit: Int) -> Int {
        guard let emptyIndex = board.firstIndex(of: 0) else { return 1 }

        let row = emptyIndex / 9
        let column = emptyIndex % 9
        var count = 0

        for number in 1...9 where canPlace(number, row: row, column: column, board: board) {
            board[emptyIndex] = number
            count += solveCount(&board, limit: limit)
            if count >= limit {
                board[emptyIndex] = 0
                return count
            }
            board[emptyIndex] = 0
        }

        return count
    }

    private func canPlace(_ value: Int, row: Int, column: Int, board: [Int]) -> Bool {
        for index in 0..<9 {
            if board[row * 9 + index] == value { return false }
            if board[index * 9 + column] == value { return false }
        }

        let startRow = (row / 3) * 3
        let startColumn = (column / 3) * 3
        for rowOffset in 0..<3 {
            for colOffset in 0..<3 {
                let idx = (startRow + rowOffset) * 9 + (startColumn + colOffset)
                if board[idx] == value { return false }
            }
        }

        return true
    }
}
