import Foundation

enum SudokuValidator {
    static func isPlacementLegal(_ value: Int, at position: CellPosition, boardValues: [Int?]) -> Bool {
        guard (1...9).contains(value) else { return false }

        let rowRange = position.row * 9..<(position.row * 9 + 9)
        for index in rowRange where index != (position.row * 9 + position.column) {
            if boardValues[index] == value { return false }
        }

        for row in 0..<9 {
            let index = row * 9 + position.column
            if row != position.row, boardValues[index] == value { return false }
        }

        let startRow = (position.row / 3) * 3
        let startColumn = (position.column / 3) * 3
        for row in startRow..<(startRow + 3) {
            for column in startColumn..<(startColumn + 3) {
                if row == position.row, column == position.column { continue }
                if boardValues[row * 9 + column] == value { return false }
            }
        }

        return true
    }

    static func rowCompleted(_ row: Int, boardValues: [Int?]) -> Bool {
        let slice = boardValues[(row * 9)..<(row * 9 + 9)]
        return Set(slice.compactMap { $0 }) == Set(1...9)
    }

    static func columnCompleted(_ column: Int, boardValues: [Int?]) -> Bool {
        let numbers = (0..<9).compactMap { boardValues[$0 * 9 + column] }
        return Set(numbers) == Set(1...9)
    }

    static func boxCompleted(_ box: Int, boardValues: [Int?]) -> Bool {
        let startRow = (box / 3) * 3
        let startColumn = (box % 3) * 3
        var numbers: [Int] = []

        for row in startRow..<(startRow + 3) {
            for column in startColumn..<(startColumn + 3) {
                guard let value = boardValues[row * 9 + column] else { return false }
                numbers.append(value)
            }
        }

        return Set(numbers) == Set(1...9)
    }
}
