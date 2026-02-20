import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(red: 0.93, green: 0.93, blue: 0.94)
    static let card = Color(red: 0.86, green: 0.86, blue: 0.87)
    static let textPrimary = Color.black
    static let textSecondary = Color.black.opacity(0.55)
    static let accent = Color.black
}

extension Font {
    static func vonique(_ size: CGFloat, fallbackWeight: Font.Weight = .regular) -> Font {
        if let loaded = FontLoader.voniquePostScriptName {
            return .custom(loaded, size: size)
        }

        let candidates = ["Vonique64", "Vonique 64", "Vonique64-Regular"]
        if let resolved = candidates.first(where: { UIFont(name: $0, size: size) != nil }) {
            return .custom(resolved, size: size)
        }
        return .system(size: size, weight: fallbackWeight, design: .rounded)
    }

    static func highlandBoard(_ size: CGFloat, fallbackWeight: Font.Weight = .regular) -> Font {
        if let loaded = FontLoader.highlandPostScriptName {
            return .custom(loaded, size: size)
        }

        let candidates = ["HighlandGothicFLF-Bold", "Highland Gothic FLF Bold", "HighlandGothicFLFBold"]
        if let resolved = candidates.first(where: { UIFont(name: $0, size: size) != nil }) {
            return .custom(resolved, size: size)
        }
        return .system(size: size, weight: fallbackWeight, design: .rounded)
    }

    static func titilliumBoard(_ size: CGFloat, fallbackWeight: Font.Weight = .regular) -> Font {
        if let loaded = FontLoader.titilliumPostScriptName {
            return .custom(loaded, size: size)
        }

        let candidates = ["TitilliumWeb-Light", "TitilliumWeb-LightItalic", "Titillium Web"]
        if let resolved = candidates.first(where: { UIFont(name: $0, size: size) != nil }) {
            return .custom(resolved, size: size)
        }
        return .system(size: size, weight: fallbackWeight, design: .rounded)
    }
}
