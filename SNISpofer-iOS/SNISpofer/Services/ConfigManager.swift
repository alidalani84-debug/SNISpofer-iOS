// ConfigManager.swift - Loads and saves AppConfig via App Groups
import Foundation

class ConfigManager {

    static let shared = ConfigManager()
    private init() {}

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    func save(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults?.set(data, forKey: AppGroup.configKey)
    }

    func load() -> AppConfig {
        guard
            let data   = defaults?.data(forKey: AppGroup.configKey),
            let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else { return .default }
        return config
    }

    func appendLog(_ message: String) {
        var logs = getLogs()
        let ts   = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("[\(ts)] \(message)")
        if logs.count > 500 { logs = Array(logs.suffix(500)) }
        defaults?.set(logs, forKey: AppGroup.logsKey)
    }

    func getLogs() -> [String] {
        defaults?.stringArray(forKey: AppGroup.logsKey) ?? []
    }

    func clearLogs() {
        defaults?.removeObject(forKey: AppGroup.logsKey)
    }
}
