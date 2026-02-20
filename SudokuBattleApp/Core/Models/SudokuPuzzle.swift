import Foundation

struct SudokuPuzzle: Codable {
    let id: String
    let difficulty: SudokuDifficulty
    let cells: [SudokuCell]
}
