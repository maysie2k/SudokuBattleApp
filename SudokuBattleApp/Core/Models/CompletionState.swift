import Foundation

struct CompletionState: Codable {
    var completedRows: Set<Int> = []
    var completedColumns: Set<Int> = []
    var completedBoxes: Set<Int> = []
}
