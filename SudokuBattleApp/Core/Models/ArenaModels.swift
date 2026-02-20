import Foundation

enum ArenaPunishmentType: String, CaseIterable, Codable {
    case pause = "Pause!"
    case whereDidYouGo = "Hidden!"
    case byeBye = "Bye! Bye!"
    case fade = "Fade!"
    case youSquare = "Square!"

    var duration: Int {
        switch self {
        case .pause: return 5
        case .whereDidYouGo: return 10
        case .byeBye: return 0
        case .fade: return 10
        case .youSquare: return 10
        }
    }
}

struct ArenaPunishmentState {
    var type: ArenaPunishmentType
    var remainingSeconds: Int
}
