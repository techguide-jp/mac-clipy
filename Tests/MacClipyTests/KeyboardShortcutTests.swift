import XCTest
@testable import MacClipy

final class KeyboardShortcutTests: XCTestCase {
    func testDefaultShortcutIsShiftCommandV() {
        XCTAssertEqual(KeyboardShortcut.defaultShortcut.editingString, "shift+command+v")
        XCTAssertEqual(KeyboardShortcut.defaultShortcut.displayName, "⇧⌘V")
    }

    func testDefaultFavoriteShortcutIsOptionCommandV() {
        XCTAssertEqual(KeyboardShortcut.defaultFavoriteShortcut.editingString, "option+command+v")
        XCTAssertEqual(KeyboardShortcut.defaultFavoriteShortcut.displayName, "⌥⌘V")
    }

    func testParseShortcutText() throws {
        XCTAssertEqual(try KeyboardShortcut.parse("shift + command + v"), .defaultShortcut)
        XCTAssertEqual(try KeyboardShortcut.parse("cmd shift V"), .defaultShortcut)
        XCTAssertEqual(
            try KeyboardShortcut.parse("control+option+space"),
            KeyboardShortcut(key: "space", modifiers: [.control, .option])
        )
    }

    func testRejectsShortcutWithoutModifier() {
        XCTAssertThrowsError(try KeyboardShortcut.parse("v")) { error in
            XCTAssertEqual(error as? KeyboardShortcutParseError, .missingModifier)
        }
    }

    func testRejectsShiftOnlyShortcut() {
        XCTAssertThrowsError(try KeyboardShortcut.parse("shift+v")) { error in
            XCTAssertEqual(error as? KeyboardShortcutParseError, .missingModifier)
        }
    }

    func testRejectsEscapeShortcut() {
        XCTAssertThrowsError(try KeyboardShortcut.parse("command+escape")) { error in
            XCTAssertEqual(error as? KeyboardShortcutParseError, .unsupportedKey("escape"))
        }
    }

    func testKeyLookupFromCarbonKeyCode() throws {
        let keyCode = try XCTUnwrap(KeyboardShortcut.defaultShortcut.carbonKeyCode)
        XCTAssertEqual(KeyboardShortcut.key(forCarbonKeyCode: keyCode), "v")
    }

    func testSettingsDecodeUsesDefaultHotKeyWhenMissing() throws {
        let json = """
        {
          "excludedBundleIdentifiers": ["com.example.Secret"]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.excludedBundleIdentifiers, ["com.example.Secret"])
        XCTAssertEqual(settings.hotKey, .defaultShortcut)
        XCTAssertEqual(settings.favoriteHotKey, .defaultFavoriteShortcut)
    }

    func testSettingsDecodeUsesDefaultHotKeyWhenStoredHotKeyIsUnsupported() throws {
        let json = """
        {
          "excludedBundleIdentifiers": ["com.example.Secret"],
          "hotKey": {
            "key": "escape",
            "modifiers": ["command"]
          }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.hotKey, .defaultShortcut)
        XCTAssertEqual(settings.favoriteHotKey, .defaultFavoriteShortcut)
    }

    func testSettingsDecodeUsesDefaultFavoriteHotKeyWhenStoredHotKeyIsUnsupported() throws {
        let json = """
        {
          "excludedBundleIdentifiers": ["com.example.Secret"],
          "favoriteHotKey": {
            "key": "escape",
            "modifiers": ["command"]
          }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.favoriteHotKey, .defaultFavoriteShortcut)
    }
}
