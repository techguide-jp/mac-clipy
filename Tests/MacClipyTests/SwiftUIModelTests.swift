import AppKit
import Carbon
@testable import MacClipy
import XCTest

@MainActor
final class SwiftUIModelTests: XCTestCase {
    func testClipboardHistoryModelRefreshesSearchableItems() throws {
        let model = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        try model.store.add(content: "alpha note", sourceBundleID: nil)
        try model.store.add(content: "beta note", sourceBundleID: nil)

        model.refreshFromStore()

        XCTAssertEqual(model.items.map(\.content), ["beta note", "alpha note"])
        XCTAssertEqual(model.search("alpha").map(\.content), ["alpha note"])
    }

    func testClipboardMonitorCapturesPasteboardImmediatelyForPopupDisplay() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MacClipyTests-\(UUID().uuidString)"))
        pasteboard.clearContents()

        let store = ClipboardStore(historyURL: temporaryHistoryURL())
        var changeCount = 0
        let monitor = ClipboardMonitor(
            store: store,
            excludedBundleIdentifiers: { [] },
            pasteboard: pasteboard,
            onChange: {
                changeCount += 1
            }
        )

        pasteboard.clearContents()
        pasteboard.setString("instant clip", forType: .string)

        XCTAssertTrue(monitor.captureCurrentPasteboardIfNeeded(sourceBundleID: "com.example.Editor"))
        XCTAssertEqual(store.items.map(\.content), ["instant clip"])
        XCTAssertEqual(store.items.first?.sourceBundleID, "com.example.Editor")
        XCTAssertEqual(changeCount, 1)
    }

    func testHistoryPopupArrowKeysMoveSelectionWhenSearchFieldFocused() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        try historyModel.store.add(content: "first", sourceBundleID: nil, at: Date(timeIntervalSince1970: 10))
        try historyModel.store.add(content: "second", sourceBundleID: nil, at: Date(timeIntervalSince1970: 20))
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        )
        popupModel.prepare(initialMode: .all)

        XCTAssertTrue(
            try HistoryPopupKeyAction.handle(
                event: keyEvent(keyCode: kVK_DownArrow),
                isTextEditing: true,
                model: popupModel
            )
        )
        XCTAssertEqual(popupModel.selectedRow, 1)

        XCTAssertTrue(
            try HistoryPopupKeyAction.handle(
                event: keyEvent(keyCode: kVK_UpArrow),
                isTextEditing: true,
                model: popupModel
            )
        )
        XCTAssertEqual(popupModel.selectedRow, 0)
    }

    func testHistoryPopupChoosesDisplayedSnapshotWhenStoreChangesBeforeRefresh() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        try historyModel.store.add(content: "first", sourceBundleID: nil, at: Date(timeIntervalSince1970: 10))
        try historyModel.store.add(content: "second", sourceBundleID: nil, at: Date(timeIntervalSince1970: 20))
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        )
        popupModel.prepare(initialMode: .all)
        let displayedResult = popupModel.results[1]
        var chosenItem: ClipboardItem?
        popupModel.onChoose = { item in
            chosenItem = item
        }

        try historyModel.store.add(content: "third", sourceBundleID: nil, at: Date(timeIntervalSince1970: 30))
        popupModel.chooseItem(at: 1)

        XCTAssertEqual(chosenItem?.id, displayedResult.item.id)
        XCTAssertEqual(chosenItem?.content, "first")
    }

    func testHistoryPopupPrepareResetsSearchPresentationState() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        try historyModel.store.add(content: "first", sourceBundleID: nil)
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        )

        popupModel.prepare(initialMode: .all)
        let firstPresentationRevision = popupModel.presentationRevision
        popupModel.query = "stale search"

        popupModel.prepare(initialMode: .all)

        XCTAssertEqual(popupModel.query, "")
        XCTAssertGreaterThan(popupModel.presentationRevision, firstPresentationRevision)
    }

    func testHistoryPopupHistoryResultKeepsClipboardIdentityWhenFavorited() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        let favoriteStore = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let item = try XCTUnwrap(
            try historyModel.store.add(content: "favorite source", sourceBundleID: nil, at: Date(timeIntervalSince1970: 10))
        )
        let favorite = try favoriteStore.addFavorite(for: item)
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: favoriteStore)
        )

        popupModel.prepare(initialMode: .all)

        XCTAssertEqual(popupModel.results.first?.id, item.id)
        XCTAssertNotEqual(popupModel.results.first?.id, favorite.id)
    }

    func testHistoryPopupDisplaysCopiedContentBeforeCustomFavoriteTitleInHistoryMode() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        let favoriteStore = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let item = try XCTUnwrap(
            try historyModel.store.add(content: "copied body", sourceBundleID: nil, at: Date(timeIntervalSince1970: 10))
        )
        try favoriteStore.addFavorite(for: item, displayTitle: "custom favorite name")
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: favoriteStore)
        )

        popupModel.prepare(initialMode: .all)

        XCTAssertEqual(popupModel.results.first?.title, "copied body")
        XCTAssertEqual(popupModel.results.first?.detail, "custom favorite name")
    }

    func testHistoryPopupDisplaysCopiedContentBeforeCustomFavoriteTitleInFavoritesMode() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        let favoriteStore = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let item = makeItem(content: "favorite copied body", at: 10)
        try favoriteStore.addFavorite(for: item, displayTitle: "custom favorite name")
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: favoriteStore)
        )

        popupModel.prepare(initialMode: .favorites)

        XCTAssertEqual(popupModel.results.first?.title, "favorite copied body")
        XCTAssertEqual(popupModel.results.first?.detail, "custom favorite name")
    }

    func testHistoryPopupFavoritesModeChoosesItemMatchingDisplayedTitle() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        let favoriteStore = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let item = makeItem(content: "favorite copied body", at: 10)
        try favoriteStore.addFavorite(for: item, displayTitle: "custom favorite name")
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: favoriteStore)
        )
        var chosenItem: ClipboardItem?
        popupModel.onChoose = { item in
            chosenItem = item
        }

        popupModel.prepare(initialMode: .favorites)
        let displayedResult = try XCTUnwrap(popupModel.results.first)
        popupModel.chooseItem(id: displayedResult.id)

        XCTAssertEqual(chosenItem?.menuTitle, displayedResult.title)
        XCTAssertEqual(chosenItem?.content, "favorite copied body")
    }

    func testFavoritesModelFiltersAssignsAndRemovesFolders() throws {
        let model = FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        let favorite = try model.store.addFavorite(for: makeItem(content: "deploy command", at: 10))
        let folder = try model.store.createFolder(named: "Work")
        model.refreshFromStore()

        model.selectFavorite(favorite)
        model.addSelectedFavorite(to: folder.id)
        model.selectFolderFilter(.folder(folder.id))

        XCTAssertEqual(model.visibleItems().map(\.id), [favorite.id])
        XCTAssertEqual(model.folderIDs(for: favorite.id), [folder.id])

        model.removeSelectedFavorite(from: folder.id)
        model.selectFolderFilter(.unclassified)

        XCTAssertEqual(model.visibleItems().map(\.id), [favorite.id])
    }

    func testFavoritesModelRefreshPreservesSelectedFolderFilter() {
        let model = FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        let folderID = UUID()

        model.selectFolderFilter(.folder(folderID))
        model.refreshFromStore()

        XCTAssertEqual(model.selectedFolderFilter, .folder(folderID))
    }

    private func makeItem(content: String, at timestamp: TimeInterval) -> ClipboardItem {
        ClipboardItem(
            content: content,
            sourceBundleID: "com.example.Source",
            createdAt: Date(timeIntervalSince1970: timestamp),
            lastUsedAt: Date(timeIntervalSince1970: timestamp),
            useCount: 1
        )
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

    private func keyEvent(keyCode: Int) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: UInt16(keyCode)
        ))
    }
}
