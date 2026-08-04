import Foundation
@testable import MacClipy
import XCTest

final class HistoryPopupAnalyticsTests: XCTestCase {
    func testReportsPresentationAndOneSearchSessionPerOpen() async throws {
        try await MainActor.run {
            let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: Self.temporaryHistoryURL()))
            try historyModel.store.add(content: "first", sourceBundleID: nil)
            let popupModel = HistoryPopupModel(
                historyModel: historyModel,
                favoritesModel: FavoritesModel(store: FavoriteStore(favoritesURL: Self.temporaryFavoritesURL()))
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
    }

    func testReportsItemUseSourceWithoutItemData() async throws {
        try await MainActor.run {
            let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: Self.temporaryHistoryURL()))
            let historyItem = try XCTUnwrap(
                try historyModel.store.add(content: "first", sourceBundleID: nil)
            )
            let favoriteStore = FavoriteStore(favoritesURL: Self.temporaryFavoritesURL())
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
    }

    func testReportsSuccessfulFavoriteRemoval() async throws {
        try await MainActor.run {
            let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: Self.temporaryHistoryURL()))
            let historyItem = try XCTUnwrap(
                try historyModel.store.add(content: "first", sourceBundleID: nil)
            )
            let favoriteStore = FavoriteStore(favoritesURL: Self.temporaryFavoritesURL())
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
    }

    func testFavoritesModelReportsSuccessfulFavoriteRemoval() async throws {
        Self.reportProgress("favorite removal test entered")
        try await MainActor.run {
            Self.reportProgress("favorite removal main actor entered")
            let model = FavoritesModel(store: FavoriteStore(favoritesURL: Self.temporaryFavoritesURL()))
            Self.reportProgress("favorite removal model created")
            let favorite = try model.store.addFavorite(for: Self.makeItem(content: "remove me", at: 10))
            Self.reportProgress("favorite removal favorite added")
            model.refreshFromStore()
            model.selectFavorite(favorite)
            var managementCount = 0
            model.onFavoriteManagement = { managementCount += 1 }

            Self.reportProgress("favorite removal removing")
            model.removeSelectedFavorite()
            Self.reportProgress("favorite removal removed")

            XCTAssertEqual(managementCount, 1)
            XCTAssertTrue(model.items.isEmpty)
            Self.reportProgress("favorite removal assertions completed")
        }
    }

    private static func reportProgress(_ message: String) {
        FileHandle.standardError.write(Data("[HistoryPopupAnalyticsTests] \(message)\n".utf8))
    }

    private static func makeItem(content: String, at timestamp: TimeInterval) -> ClipboardItem {
        ClipboardItem(
            content: content,
            sourceBundleID: "com.example.Source",
            createdAt: Date(timeIntervalSince1970: timestamp),
            lastUsedAt: Date(timeIntervalSince1970: timestamp),
            useCount: 1
        )
    }

    private static func temporaryHistoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    private static func temporaryFavoritesURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("favorites.json")
    }
}
