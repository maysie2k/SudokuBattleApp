import Foundation

enum SudokuDifficulty: String, CaseIterable, Codable, Identifiable {
    case simple
    case medium
    case hard
    case master

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple: return "Simple"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .master: return "Master"
        }
    }

    var emptyCells: Int {
        switch self {
        case .simple: return 29
        case .medium: return 40
        case .hard: return 46
        case .master: return 55
        }
    }
}
