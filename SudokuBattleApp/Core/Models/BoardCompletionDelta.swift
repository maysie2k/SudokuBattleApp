import Foundation

struct BoardCompletionDelta {
    var newRows: Set<Int> = []
    var newColumns: Set<Int> = []
    var newBoxes: Set<Int> = []

    var hasAny: Bool {
        !newRows.isEmpty || !newColumns.isEmpty || !newBoxes.isEmpty
    }
}
