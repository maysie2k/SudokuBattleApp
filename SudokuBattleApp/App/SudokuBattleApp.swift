import SwiftUI
import FirebaseCore

@main
struct SudokuBattleApp: App {
    init() {
        FirebaseApp.configure()
        _ = FontLoader.registerVoniqueIfNeeded()
        _ = FontLoader.registerTitilliumIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootMenuView()
                .preferredColorScheme(.light)
        }
    }
}
