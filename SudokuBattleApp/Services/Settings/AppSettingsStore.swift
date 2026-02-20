import Foundation
import Combine

final class AppSettingsStore {
    static let shared = AppSettingsStore()

    private let userDefaults = UserDefaults.standard
    private let key = "arena.app.settings.v1"

    private init() {}

    func load() -> AppSettings {
        guard
            let data = userDefaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: key)
    }
}
