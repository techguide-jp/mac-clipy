import Defaults
import KeyboardShortcuts
import XCTest
@testable import MacClipy

final class SettingsMigrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetDefaults()
    }

    override func tearDown() {
        resetDefaults()
        super.tearDown()
    }

    func testMigratesLegacySettingsJSONOnce() throws {
        let settingsURL = temporarySettingsURL()
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try legacyJSON(
            excludedBundleIdentifiers: [" com.example.Secret ", "COM.EXAMPLE.SECRET", "com.example.Other"],
            hotKey: #"{"key":"space","modifiers":["control","option"]}"#,
            favoriteHotKey: #"{"key":"v","modifiers":["command","option"]}"#
        )
        .write(to: settingsURL, atomically: true, encoding: .utf8)

        try SettingsMigration.migrateIfNeeded(settingsURL: settingsURL)

        XCTAssertEqual(Defaults[.excludedBundleIdentifiers], ["com.example.Secret", "com.example.Other"])
        XCTAssertEqual(
            KeyboardShortcuts.getShortcut(for: .showHistory),
            KeyboardShortcuts.Shortcut(.space, modifiers: [.control, .option])
        )
        XCTAssertEqual(
            KeyboardShortcuts.getShortcut(for: .showFavorites),
            KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .option])
        )

        try legacyJSON(
            excludedBundleIdentifiers: ["com.example.Replaced"],
            hotKey: #"{"key":"a","modifiers":["command"]}"#,
            favoriteHotKey: #"{"key":"b","modifiers":["command"]}"#
        )
        .write(to: settingsURL, atomically: true, encoding: .utf8)

        try SettingsMigration.migrateIfNeeded(settingsURL: settingsURL)

        XCTAssertEqual(Defaults[.excludedBundleIdentifiers], ["com.example.Secret", "com.example.Other"])
        XCTAssertEqual(
            KeyboardShortcuts.getShortcut(for: .showHistory),
            KeyboardShortcuts.Shortcut(.space, modifiers: [.control, .option])
        )
    }

    private func legacyJSON(
        excludedBundleIdentifiers: [String],
        hotKey: String,
        favoriteHotKey: String
    ) -> String {
        let identifiers = excludedBundleIdentifiers
            .map { #""\#($0)""# }
            .joined(separator: ",")
        return """
        {
          "excludedBundleIdentifiers": [\(identifiers)],
          "hotKey": \(hotKey),
          "favoriteHotKey": \(favoriteHotKey)
        }
        """
    }

    private func temporarySettingsURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    private func resetDefaults() {
        Defaults.Keys.excludedBundleIdentifiers.reset()
        Defaults.Keys.didMigrateLegacySettings.reset()
        KeyboardShortcuts.setShortcut(nil, for: .showHistory)
        KeyboardShortcuts.setShortcut(nil, for: .showFavorites)
    }
}
