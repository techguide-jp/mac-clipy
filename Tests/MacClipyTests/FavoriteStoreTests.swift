import XCTest
@testable import MacClipy

final class FavoriteStoreTests: XCTestCase {
    func testToggleFavoritePersistsSnapshot() throws {
        let url = temporaryFavoritesURL()
        let store = FavoriteStore(favoritesURL: url)
        let item = makeItem(content: "keep me", at: 10)

        XCTAssertTrue(try store.toggleFavorite(for: item, at: Date(timeIntervalSince1970: 20)))
        XCTAssertTrue(store.isFavorite(item))
        XCTAssertEqual(store.items.first?.contentSnapshot, "keep me")

        let restored = FavoriteStore(favoritesURL: url)
        try restored.load()

        XCTAssertEqual(restored.items.count, 1)
        XCTAssertEqual(restored.items.first?.contentSnapshot, "keep me")
    }

    func testToggleFavoriteRemovesExistingFavorite() throws {
        let store = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let item = makeItem(content: "toggle", at: 10)

        try store.addFavorite(for: item)
        XCTAssertFalse(try store.toggleFavorite(for: item))

        XCTAssertFalse(store.isFavorite(item))
        XCTAssertTrue(store.items.isEmpty)
    }

    func testFolderMembershipAllowsMultipleFolders() throws {
        let store = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let favorite = try store.addFavorite(for: makeItem(content: "multi folder", at: 10))
        let firstFolder = try store.createFolder(named: "Work", at: Date(timeIntervalSince1970: 20))
        let secondFolder = try store.createFolder(named: "Private", at: Date(timeIntervalSince1970: 30))

        try store.addFavorite(id: favorite.id, to: firstFolder.id)
        try store.addFavorite(id: favorite.id, to: secondFolder.id)

        XCTAssertEqual(Set(store.folderIDs(for: favorite.id)), Set([firstFolder.id, secondFolder.id]))
        XCTAssertEqual(store.search("", folderID: firstFolder.id).map(\.id), [favorite.id])
        XCTAssertEqual(store.search("", folderID: secondFolder.id).map(\.id), [favorite.id])
    }

    func testFoldersAndMembershipsPersistWithOrdering() throws {
        let url = temporaryFavoritesURL()
        let store = FavoriteStore(favoritesURL: url)
        let favorite = try store.addFavorite(for: makeItem(content: "persist folder", at: 10))
        let firstFolder = try store.createFolder(named: "First", at: Date(timeIntervalSince1970: 20))
        let secondFolder = try store.createFolder(named: "Second", at: Date(timeIntervalSince1970: 30))

        try store.addFavorite(id: favorite.id, to: firstFolder.id)
        try store.addFavorite(id: favorite.id, to: secondFolder.id)
        try store.renameFolder(id: secondFolder.id, name: "Renamed")
        try store.moveFolder(id: secondFolder.id, by: -1)

        let restored = FavoriteStore(favoritesURL: url)
        try restored.load()

        XCTAssertEqual(restored.folders.map(\.name), ["Renamed", "First"])
        XCTAssertEqual(Set(restored.folderIDs(for: favorite.id)), Set([firstFolder.id, secondFolder.id]))
    }

    func testDeletingFolderLeavesFavoriteUnclassified() throws {
        let store = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let favorite = try store.addFavorite(for: makeItem(content: "orphan", at: 10))
        let folder = try store.createFolder(named: "Temporary")
        try store.addFavorite(id: favorite.id, to: folder.id)

        try store.deleteFolder(id: folder.id)

        XCTAssertEqual(store.folders.count, 0)
        XCTAssertEqual(store.unclassifiedItems().map(\.id), [favorite.id])
    }

    func testDisplayTitleAndUsageAreUpdated() throws {
        let store = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let favorite = try store.addFavorite(for: makeItem(content: "original title", at: 10))

        try store.updateDisplayTitle(id: favorite.id, title: "Renamed")
        try store.markUsed(id: favorite.id, at: Date(timeIntervalSince1970: 40))

        let updated = try XCTUnwrap(store.items.first)
        XCTAssertEqual(updated.displayTitle, "Renamed")
        XCTAssertEqual(updated.lastUsedAt, Date(timeIntervalSince1970: 40))
        XCTAssertEqual(updated.useCount, 2)
    }

    func testAddFavoriteUsesCustomDisplayTitle() throws {
        let store = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let favorite = try store.addFavorite(
            for: makeItem(content: "default title", at: 10),
            displayTitle: "Custom Name"
        )

        XCTAssertEqual(favorite.displayTitle, "Custom Name")
        XCTAssertEqual(store.items.first?.menuTitle, "Custom Name")
        XCTAssertEqual(store.items.first?.contentMenuTitle, "default title")
        XCTAssertEqual(store.items.first?.hasCustomDisplayTitle, true)
    }

    func testDefaultFavoriteTitleIsNotTreatedAsCustom() throws {
        let store = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let favorite = try store.addFavorite(for: makeItem(content: "default title", at: 10))

        XCTAssertEqual(favorite.menuTitle, "default title")
        XCTAssertEqual(favorite.contentMenuTitle, "default title")
        XCTAssertFalse(favorite.hasCustomDisplayTitle)
    }

    func testFavoriteSnapshotSurvivesHistoryTrim() throws {
        let historyStore = ClipboardStore(historyURL: temporaryHistoryURL(), maxItems: 1)
        let favoriteStore = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let favoriteSource = try XCTUnwrap(
            try historyStore.add(content: "important", sourceBundleID: nil, at: Date(timeIntervalSince1970: 10))
        )

        try favoriteStore.addFavorite(for: favoriteSource)
        try historyStore.add(content: "newer", sourceBundleID: nil, at: Date(timeIntervalSince1970: 20))

        XCTAssertEqual(historyStore.items.map(\.content), ["newer"])
        XCTAssertEqual(favoriteStore.items.first?.contentSnapshot, "important")
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

    private func temporaryFavoritesURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("favorites.json")
    }

    private func temporaryHistoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("history.json")
    }
}
