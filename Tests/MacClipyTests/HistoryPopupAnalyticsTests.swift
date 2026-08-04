import Foundation
@testable import MacClipy
import XCTest

@MainActor
final class HistoryPopupAnalyticsTests: XCTestCase {
    func testReportsPresentationAndOneSearchSessionPerOpen() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        try historyModel.store.add(content: "first", sourceBundleID: nil)
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        )
        var presentedModes: [HistoryPopupInitialMode] = []
        var searchSessionCount = 0
        popupModel.onPresented = { presentedModes.append($0) }
        popupModel.onSearchSession = { searchSessionCount += 1 }

        popupModel.prepare(initialMode: .all)
        popupModel.query = "f"
        popupModel.query = "fi"
        popupModel.query = ""
        popupModel.query = "first"
        popupModel.prepare(initialMode: .favorites)
        popupModel.query = "f"

        XCTAssertEqual(presentedModes, [.all, .favorites])
        XCTAssertEqual(searchSessionCount, 2)
    }

    func testReportsItemUseSourceWithoutItemData() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        let historyItem = try XCTUnwrap(
            try historyModel.store.add(content: "first", sourceBundleID: nil)
        )
        let favoriteStore = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        try favoriteStore.addFavorite(for: historyItem)
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: favoriteStore)
        )
        var usedSources: [AnalyticsItemSource] = []
        popupModel.onItemUsed = { usedSources.append($0) }

        popupModel.prepare(initialMode: .all)
        popupModel.chooseSelectedItem()
        popupModel.prepare(initialMode: .favorites)
        popupModel.chooseSelectedItem()

        XCTAssertEqual(usedSources, [.history, .favorite])
    }

    func testReportsSuccessfulFavoriteRemoval() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        let historyItem = try XCTUnwrap(
            try historyModel.store.add(content: "first", sourceBundleID: nil)
        )
        let favoriteStore = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        try favoriteStore.addFavorite(for: historyItem)
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: favoriteStore)
        )
        var managementCount = 0
        popupModel.onFavoriteManagement = { managementCount += 1 }

        popupModel.prepare(initialMode: .favorites)
        let favoriteID = try XCTUnwrap(popupModel.results.first?.id)
        popupModel.toggleFavorite(id: favoriteID)

        XCTAssertEqual(managementCount, 1)
        XCTAssertTrue(favoriteStore.items.isEmpty)
    }

    func testFavoritesModelReportsSuccessfulFavoriteRemoval() throws {
        let model = FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        let favorite = try model.store.addFavorite(for: makeItem(content: "remove me", at: 10))
        model.refreshFromStore()
        model.selectFavorite(favorite)
        var managementCount = 0
        model.onFavoriteManagement = { managementCount += 1 }

        model.removeSelectedFavorite()

        XCTAssertEqual(managementCount, 1)
        XCTAssertTrue(model.items.isEmpty)
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
}
