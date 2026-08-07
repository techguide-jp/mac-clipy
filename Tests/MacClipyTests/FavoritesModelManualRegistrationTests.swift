import Foundation
@testable import MacClipy
import XCTest

@MainActor
final class FavoritesModelManualRegistrationTests: XCTestCase {
    func testAddsManualFavoriteToSelectedFolder() throws {
        let model = FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        let folder = try model.store.createFolder(named: "Work")
        model.refreshFromStore()
        model.selectFolderFilter(.folder(folder.id))
        var managementCount = 0
        model.onFavoriteManagement = { managementCount += 1 }

        XCTAssertTrue(model.addManualFavorite(content: "deploy command", displayTitle: "Deploy"))

        let favorite = try XCTUnwrap(model.items.first)
        XCTAssertEqual(favorite.contentSnapshot, "deploy command")
        XCTAssertEqual(favorite.displayTitle, "Deploy")
        XCTAssertEqual(model.selectedFavoriteID, favorite.id)
        XCTAssertEqual(model.folderIDs(for: favorite.id), [folder.id])
        XCTAssertEqual(model.visibleItems().map(\.id), [favorite.id])
        XCTAssertEqual(managementCount, 1)
    }

    func testKeepsManualFavoriteDraftWhenRegistrationFails() {
        let model = FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))

        XCTAssertFalse(model.addManualFavorite(content: "  \n ", displayTitle: "Empty"))

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNil(model.selectedFavoriteID)
        XCTAssertFalse(model.statusMessage.isEmpty)
    }

    private func temporaryFavoritesURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("favorites.json")
    }
}
