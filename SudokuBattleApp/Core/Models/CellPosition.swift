import Foundation

struct CellPosition: Hashable, Codable {
    let row: Int
    let column: Int

    var boxIndex: Int {
        (row / 3) * 3 + (column / 3)
    }
}
