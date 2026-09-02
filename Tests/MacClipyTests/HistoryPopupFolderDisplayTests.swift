import Foundation
@testable import MacClipy
import XCTest

@MainActor
final class HistoryPopupFolderDisplayTests: XCTestCase {
    func testAllFoldersShowsEveryMembershipAndUnclassifiedLabel() throws {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        let favoriteStore = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let classified = try favoriteStore.addManualFavorite(content: "classified", displayTitle: "")
        let unclassified = try favoriteStore.addManualFavorite(content: "unclassified", displayTitle: "")
        let work = try favoriteStore.createFolder(named: "Work")
        let privateFolder = try favoriteStore.createFolder(named: "Private")
        try favoriteStore.addFavorite(id: classified.id, to: work.id)
        try favoriteStore.addFavorite(id: classified.id, to: privateFolder.id)
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: favoriteStore)
        )

        popupModel.prepare(initialMode: .favorites)

        let classifiedResult = try XCTUnwrap(popupModel.results.first { $0.id == classified.id })
        XCTAssertEqual(classifiedResult.folderNames, ["Private", "Work"])
        let unclassifiedResult = try XCTUnwrap(popupModel.results.first { $0.id == unclassified.id })
        XCTAssertEqual(unclassifiedResult.folderNames, [L10n.tr("historyPopup.folders.unclassified")])
    }

    func testSpecificFolderAndHistoryModeHideFolderNames() throws {
        let historyStore = ClipboardStore(historyURL: temporaryHistoryURL())
        let historyItem = try XCTUnwrap(try historyStore.add(content: "shared", sourceBundleID: nil))
        let historyModel = ClipboardHistoryModel(store: historyStore)
        let favoriteStore = FavoriteStore(favoritesURL: temporaryFavoritesURL())
        let favorite = try favoriteStore.addFavorite(for: historyItem)
        let folder = try favoriteStore.createFolder(named: "Work")
        try favoriteStore.addFavorite(id: favorite.id, to: folder.id)
        let popupModel = HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: favoriteStore)
        )

        popupModel.prepare(initialMode: .favorites)
        popupModel.selectFolderFilter(.folder(folder.id))
        XCTAssertNil(popupModel.results.first?.folderNames)

        popupModel.selectMode(.all)
        XCTAssertNil(popupModel.results.first?.folderNames)
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
