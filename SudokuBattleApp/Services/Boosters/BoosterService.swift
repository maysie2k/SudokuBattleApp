import Foundation

protocol BoosterServiceProtocol {
    func canUseBooster(_ booster: BoosterType, at date: Date) -> Bool
    func applyBooster(_ booster: BoosterType, to board: inout [SudokuCell])
}

enum BoosterType: String, CaseIterable {
    case revealCell
    case protectFromSabotage
    case extraLife
}

struct PlaceholderBoosterService: BoosterServiceProtocol {
    func canUseBooster(_ booster: BoosterType, at date: Date) -> Bool {
        false
    }

    func applyBooster(_ booster: BoosterType, to board: inout [SudokuCell]) {
        // Intentionally blank: this is the extension point for future booster mechanics.
    }
}
