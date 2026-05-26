import XCTest
@testable import MacClipy

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
