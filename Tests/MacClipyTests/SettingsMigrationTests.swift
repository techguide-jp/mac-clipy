import Defaults
import KeyboardShortcuts
@testable import MacClipy
import XCTest

final class SettingsMigrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetDefaults()
    }

    override func tearDown() {
        resetDefaults()
        super.tearDown()
    }

    func testDefaultExcludedBundleIdentifiersUseCurrentBundleID() {
        XCTAssertTrue(
            SettingsDefaults.defaultExcludedBundleIdentifiers.contains(SettingsDefaults.currentBundleIdentifier)
        )
        XCTAssertFalse(
            SettingsDefaults.defaultExcludedBundleIdentifiers.contains("com.local.MacClipy")
        )
    }

    func testDisplayNameUsesMacClipyForCurrentBundleID() {
        XCTAssertEqual(
            SettingsDefaults.displayName(for: SettingsDefaults.currentBundleIdentifier),
            "MacClipy"
        )
    }

    @MainActor
    func testResetExcludedAppsUsesCurrentBundleID() {
        let model = SettingsModel()
        model.setExcludedBundleIdentifiers(["com.example.Editor"])

        model.resetExcludedApps()

        XCTAssertEqual(model.excludedBundleIdentifiers, SettingsDefaults.defaultExcludedBundleIdentifiers)
        XCTAssertTrue(model.excludedBundleIdentifiers.contains(SettingsDefaults.currentBundleIdentifier))
        XCTAssertFalse(model.excludedBundleIdentifiers.contains("com.local.MacClipy"))
        XCTAssertEqual(Defaults[.excludedBundleIdentifiers], SettingsDefaults.defaultExcludedBundleIdentifiers)
    }

    func testMigratesExistingDefaultsFromLegacyLocalBundleIdentifier() throws {
        Defaults[.didMigrateLegacySettings] = true
        Defaults[.excludedBundleIdentifiers] = [
            "COM.LOCAL.MACCLIPY",
            "com.example.Secret",
            SettingsDefaults.currentBundleIdentifier
        ]

        try SettingsMigration.migrateIfNeeded(settingsURL: temporarySettingsURL())

        XCTAssertEqual(
            Defaults[.excludedBundleIdentifiers],
            [SettingsDefaults.currentBundleIdentifier, "com.example.Secret"]
        )
        XCTAssertTrue(Defaults[.didMigrateBundleID])
    }

    func testMigratesLegacySettingsJSONOnce() throws {
        let settingsURL = temporarySettingsURL()
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try legacyJSON(
            excludedBundleIdentifiers: [
                " com.example.Secret ",
                "COM.EXAMPLE.SECRET",
                "com.local.MacClipy",
                SettingsDefaults.currentBundleIdentifier,
                "com.example.Other"
            ],
            hotKey: #"{"key":"space","modifiers":["control","option"]}"#,
            favoriteHotKey: #"{"key":"v","modifiers":["command","option"]}"#
        )
        .write(to: settingsURL, atomically: true, encoding: .utf8)

        try SettingsMigration.migrateIfNeeded(settingsURL: settingsURL)

        XCTAssertEqual(
            Defaults[.excludedBundleIdentifiers],
            ["com.example.Secret", SettingsDefaults.currentBundleIdentifier, "com.example.Other"]
        )
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

        XCTAssertEqual(
            Defaults[.excludedBundleIdentifiers],
            ["com.example.Secret", SettingsDefaults.currentBundleIdentifier, "com.example.Other"]
        )
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
        Defaults.Keys.didMigrateBundleID.reset()
        Defaults.Keys.didEvaluateOnboardingEligibility.reset()
        Defaults.Keys.isOnboardingPending.reset()
        KeyboardShortcuts.setShortcut(nil, for: .showHistory)
        KeyboardShortcuts.setShortcut(nil, for: .showFavorites)
        KeyboardShortcuts.setShortcut(nil, for: .showHelp)
    }
}
