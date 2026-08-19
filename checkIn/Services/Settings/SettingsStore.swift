import Foundation

protocol SettingsStoring: Sendable {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

struct UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable {
    private static let key = "app.settings.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

final class InMemorySettingsStore: SettingsStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: AppSettings

    init(_ value: AppSettings = .default) {
        self.value = value
    }

    func load() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func save(_ settings: AppSettings) {
        lock.lock()
        value = settings
        lock.unlock()
    }
}
