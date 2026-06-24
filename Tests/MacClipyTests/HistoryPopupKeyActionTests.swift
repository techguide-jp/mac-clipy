import AppKit
import Carbon
@testable import MacClipy
import XCTest

@MainActor
final class HistoryPopupKeyActionTests: XCTestCase {
    func testBackspaceDeletesSearchTextWhenSearchFieldIsNotFocused() throws {
        let popupModel = try makePopupModel()
        popupModel.appendSearchText("fi")

        XCTAssertTrue(
            try HistoryPopupKeyAction.handle(
                event: keyEvent(
                    keyCode: kVK_Delete,
                    characters: "\u{7f}",
                    charactersIgnoringModifiers: "\u{7f}"
                ),
                isTextEditing: false,
                model: popupModel
            )
        )
        XCTAssertEqual(popupModel.query, "f")
        XCTAssertEqual(popupModel.results.map(\.item.content), ["first"])
    }

    func testBackspaceFallsThroughWhenSearchFieldIsFocused() throws {
        let popupModel = try makePopupModel()
        popupModel.appendSearchText("fi")

        XCTAssertFalse(
            try HistoryPopupKeyAction.handle(
                event: keyEvent(
                    keyCode: kVK_Delete,
                    characters: "\u{7f}",
                    charactersIgnoringModifiers: "\u{7f}"
                ),
                isTextEditing: true,
                model: popupModel
            )
        )
        XCTAssertEqual(popupModel.query, "fi")
    }

    func testIgnoresNonPrintableSearchEvents() throws {
        let popupModel = try makePopupModel()

        XCTAssertFalse(
            try HistoryPopupKeyAction.handle(
                event: keyEvent(
                    keyCode: kVK_Command,
                    characters: "\u{10}",
                    charactersIgnoringModifiers: "\u{10}"
                ),
                isTextEditing: false,
                model: popupModel
            )
        )
        XCTAssertEqual(popupModel.query, "")
        XCTAssertEqual(popupModel.results.map(\.item.content), ["first"])
    }

    private func makePopupModel() throws -> HistoryPopupModel {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        try historyModel.store.add(content: "first", sourceBundleID: nil, at: Date(timeIntervalSince1970: 10))
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        )
        popupModel.prepare(initialMode: .all)
        return popupModel
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
