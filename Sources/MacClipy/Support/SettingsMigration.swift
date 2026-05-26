import Defaults
import Foundation
import KeyboardShortcuts

enum SettingsMigration {
    private struct LegacySettings: Decodable {
        var excludedBundleIdentifiers: [String]?
        var hotKey: LegacyShortcutConverter.Shortcut?
        var favoriteHotKey: LegacyShortcutConverter.Shortcut?
    }

    static func migrateIfNeeded(settingsURL: URL = AppPaths.settingsURL) throws {
        guard !Defaults[.didMigrateLegacySettings] else {
            return
        }

        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            Defaults[.didMigrateLegacySettings] = true
            return
        }

        let data = try Data(contentsOf: settingsURL)
        guard !data.isEmpty else {
            Defaults[.didMigrateLegacySettings] = true
            return
        }

        let legacySettings = try JSONDecoder().decode(LegacySettings.self, from: data)
        if let identifiers = legacySettings.excludedBundleIdentifiers {
            Defaults[.excludedBundleIdentifiers] = SettingsDefaults.normalizedBundleIdentifiers(identifiers)
        }

        if let shortcut = LegacyShortcutConverter.convert(legacySettings.hotKey) {
            KeyboardShortcuts.setShortcut(shortcut, for: .showHistory)
        }

        if let shortcut = LegacyShortcutConverter.convert(legacySettings.favoriteHotKey) {
            KeyboardShortcuts.setShortcut(shortcut, for: .showFavorites)
        }

        Defaults[.didMigrateLegacySettings] = true
    }
}
