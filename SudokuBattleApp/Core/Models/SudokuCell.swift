import Foundation

struct SudokuCell: Identifiable, Codable, Hashable {
    let row: Int
    let column: Int
    let solution: Int
    let isGiven: Bool

    var value: Int?
    var id: String { "\\(row)-\\(column)" }

    var position: CellPosition {
        CellPosition(row: row, column: column)
    }
}
