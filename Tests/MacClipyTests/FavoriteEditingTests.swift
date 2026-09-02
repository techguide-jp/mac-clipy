import Foundation
@testable import MacClipy
import XCTest

final class FavoriteEditingTests: XCTestCase {
    func testUpdatesFavoriteTitleAndContentAndPersistsThem() throws {
        let url = temporaryFavoritesURL()
        let store = FavoriteStore(favoritesURL: url)
        let favorite = try store.addFavorite(
            for: makeItem(content: "original content", at: 10),
            displayTitle: "Original Name",
            at: Date(timeIntervalSince1970: 20)
        )

        try store.updateFavorite(
            id: favorite.id,
            displayTitle: "Updated Name",
            content: "  updated content\nsecond line  "
        )

        let updated = try XCTUnwrap(store.items.first)
        XCTAssertEqual(updated.displayTitle, "Updated Name")
        XCTAssertEqual(updated.contentSnapshot, "  updated content\nsecond line  ")
        XCTAssertEqual(updated.checksum, ClipboardItem.makeChecksum(for: "  updated content\nsecond line  "))
        XCTAssertNil(updated.clipboardItemID)
        XCTAssertNil(updated.sourceBundleID)

        let restored = FavoriteStore(favoritesURL: url)
        try restored.load()
        XCTAssertEqual(restored.items, [updated])
    }

    func testEmptyTitleFallsBackToUpdatedContent() throws {
        let store = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let favorite = try store.addFavorite(
            for: makeItem(content: "original content", at: 10),
            displayTitle: "Original Name"
        )

        try store.updateFavorite(id: favorite.id, displayTitle: "  ", content: "updated content")

        let updated = try XCTUnwrap(store.items.first)
        XCTAssertEqual(updated.displayTitle, "updated content")
        XCTAssertEqual(updated.menuTitle, "updated content")
        XCTAssertFalse(updated.hasCustomDisplayTitle)
    }

    func testRejectsWhitespaceOnlyContentWithoutChangingFavorite() throws {
        let store = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let favorite = try store.addFavorite(for: makeItem(content: "keep content", at: 10))

        XCTAssertThrowsError(
            try store.updateFavorite(id: favorite.id, displayTitle: "Changed", content: " \n\t ")
        ) { error in
            XCTAssertEqual(error as? FavoriteStoreError, .emptyContent)
        }
        XCTAssertEqual(store.items, [favorite])
    }

    func testRejectsContentAlreadyUsedByAnotherFavorite() throws {
        let store = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let first = try store.addFavorite(for: makeItem(content: "first content", at: 10))
        _ = try store.addFavorite(for: makeItem(content: "second content", at: 20))

        XCTAssertThrowsError(
            try store.updateFavorite(id: first.id, displayTitle: "Duplicate", content: "second content")
        ) { error in
            XCTAssertEqual(error as? FavoriteStoreError, .duplicateFavorite)
        }
        XCTAssertEqual(store.items.first(where: { $0.id == first.id }), first)
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
}

@MainActor
final class FavoritesModelEditingTests: XCTestCase {
    func testUpdatesSelectedFavoriteAndRefreshesSelection() throws {
        let model = FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        let favorite = try model.store.addManualFavorite(content: "before", displayTitle: "Before")
        model.refreshFromStore()
        model.selectFavorite(favorite)

        XCTAssertTrue(model.updateSelectedFavorite(displayTitle: "After", content: "after content"))

        let updated = try XCTUnwrap(model.items.first)
        XCTAssertEqual(updated.displayTitle, "After")
        XCTAssertEqual(updated.contentSnapshot, "after content")
        XCTAssertEqual(model.selectedFavoriteID, favorite.id)
        XCTAssertFalse(model.statusMessage.isEmpty)
    }

    private func temporaryFavoritesURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("favorites.json")
    }
}
