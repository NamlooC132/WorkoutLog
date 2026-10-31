import Foundation

/// UserDefaults keys. Views read these with `@AppStorage`; services use `AppSettings`.
enum SettingsKey {
    static let unit = "settings.unit"
    static let defaultRestSeconds = "settings.defaultRestSeconds"
    static let defaultWeightIncrement = "settings.defaultWeightIncrement"
    static let didSeedSampleData = "app.didSeedSampleData"
}

/// Read-only access to settings for non-view code.
enum AppSettings {
    static let fallbackRestSeconds = 90
    static let fallbackIncrement = 2.5

    /// Call once at launch so every reader sees the same defaults.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.unit: WeightUnit.kg.rawValue,
            SettingsKey.defaultRestSeconds: fallbackRestSeconds,
            SettingsKey.defaultWeightIncrement: fallbackIncrement
        ])
    }

    static var unit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: SettingsKey.unit) ?? "") ?? .kg
    }

    static var defaultRestSeconds: Int {
        let value = UserDefaults.standard.integer(forKey: SettingsKey.defaultRestSeconds)
        return value > 0 ? RestTime.clamp(value) : fallbackRestSeconds
    }

    static var defaultWeightIncrement: Double {
        let value = UserDefaults.standard.double(forKey: SettingsKey.defaultWeightIncrement)
        return value > 0 ? value : fallbackIncrement
    }
}
