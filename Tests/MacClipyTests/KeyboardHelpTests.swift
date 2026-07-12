import AppKit
import Carbon
import KeyboardShortcuts
@testable import MacClipy
import XCTest

@MainActor
final class KeyboardHelpTests: XCTestCase {
    override func tearDown() {
        KeyboardShortcuts.reset(.showHelp)
        super.tearDown()
    }

    func testShowHelpDefaultShortcutUsesCommandQuestionMark() {
        XCTAssertEqual(
            KeyboardShortcuts.Name.showHelp.defaultShortcut,
            KeyboardShortcuts.Shortcut(.slash, modifiers: [.command, .shift])
        )
    }

    func testKeyboardShortcutDisplayShowsNotSetWhenShortcutIsCleared() {
        KeyboardShortcuts.setShortcut(nil, for: .showHelp)

        XCTAssertEqual(
            KeyboardShortcutDisplay.displayName(for: .showHelp),
            L10n.tr("settings.shortcut.notSet")
        )
    }

    func testHistoryPopupQuestionMarkRequestsHelpWhenSearchFieldFocused() throws {
        let popupModel = HistoryPopupModel(
            historyModel: ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL())),
            favoritesModel: FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        )
        var didRequestHelp = false
        popupModel.onHelpRequested = {
            didRequestHelp = true
        }

        XCTAssertTrue(
            try HistoryPopupKeyAction.handle(
                event: keyEvent(
                    keyCode: kVK_ANSI_Slash,
                    modifierFlags: [.shift],
                    characters: "?",
                    charactersIgnoringModifiers: "/"
                ),
                isTextEditing: true,
                model: popupModel
            )
        )
        XCTAssertTrue(didRequestHelp)
        XCTAssertEqual(popupModel.query, "")
    }

    func testSettingsHelpKeyDoesNotFireWhileTextEditing() throws {
        var didRequestHelp = false

        XCTAssertFalse(
            try SettingsKeyAction.handle(
                event: keyEvent(
                    keyCode: kVK_ANSI_Slash,
                    modifierFlags: [.shift],
                    characters: "?",
                    charactersIgnoringModifiers: "/"
                ),
                isTextEditing: true,
                selectTab: { _ in },
                focusFavoritesSearch: {},
                showHelp: {
                    didRequestHelp = true
                }
            )
        )
        XCTAssertFalse(didRequestHelp)
    }

    func testSettingsCommandFSelectsFavoritesAndFocusesSearch() throws {
        var selectedTab: SettingsTab?
        var didFocusSearch = false

        XCTAssertTrue(
            try SettingsKeyAction.handle(
                event: keyEvent(
                    keyCode: kVK_ANSI_F,
                    modifierFlags: [.command],
                    characters: "f",
                    charactersIgnoringModifiers: "f"
                ),
                isTextEditing: false,
                selectTab: { selectedTab = $0 },
                focusFavoritesSearch: {
                    didFocusSearch = true
                },
                showHelp: {}
            )
        )
        XCTAssertEqual(selectedTab, .favorites)
        XCTAssertTrue(didFocusSearch)
    }

    func testSettingsCommand3SelectsExcludedApps() throws {
        var selectedTab: SettingsTab?

        XCTAssertTrue(
            try SettingsKeyAction.handle(
                event: keyEvent(
                    keyCode: kVK_ANSI_3,
                    modifierFlags: [.command],
                    characters: "3",
                    charactersIgnoringModifiers: "3"
                ),
                isTextEditing: false,
                selectTab: { selectedTab = $0 },
                focusFavoritesSearch: {},
                showHelp: {}
            )
        )
        XCTAssertEqual(selectedTab, .excludedApps)
    }

    private func temporaryHistoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    private func temporaryFavoritesURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("favorites.json")
    }

    private func keyEvent(
        keyCode: Int,
        modifierFlags: NSEvent.ModifierFlags = [],
        characters: String = "",
        charactersIgnoringModifiers: String = ""
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        ))
    }
}
