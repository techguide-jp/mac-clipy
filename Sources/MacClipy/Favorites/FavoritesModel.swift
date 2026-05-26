import Foundation
import Observation

enum FavoriteFolderFilter: Equatable, Hashable {
    case all
    case unclassified
    case folder(UUID)
}

@MainActor
@Observable
final class FavoritesModel {
    let store: FavoriteStore

    private(set) var items: [FavoriteItem] = []
    private(set) var folders: [FavoriteFolder] = []
    private(set) var memberships: [FavoriteFolderMembership] = []
    var selectedFolderFilter: FavoriteFolderFilter = .all
    var selectedFavoriteID: UUID?
    var selectedSort: FavoriteItemSort = .manual
    var statusMessage = ""
    var newFolderName = ""
    var selectedFolderName = ""
    var draftFavoriteTitle = ""

    init(store: FavoriteStore = FavoriteStore()) {
        self.store = store
    }

    func load() throws {
        try store.load()
        refreshFromStore()
    }

    func refreshFromStore() {
        items = store.items
        folders = store.folders
        memberships = store.memberships

        if case let .folder(folderID) = selectedFolderFilter {
            selectedFolderName = folders.first(where: { $0.id == folderID })?.name ?? selectedFolderName
        }

        if let selectedFavoriteID,
           !items.contains(where: { $0.id == selectedFavoriteID }) {
            self.selectedFavoriteID = nil
            draftFavoriteTitle = ""
        }
    }

    func visibleItems(query: String = "") -> [FavoriteItem] {
        switch selectedFolderFilter {
        case .all:
            store.search(query, folderID: nil, sort: selectedSort)
        case .unclassified:
            store.unclassifiedItems(sort: selectedSort).filter { favoriteMatches($0, query: query) }
        case let .folder(folderID):
            store.search(query, folderID: folderID, sort: selectedSort)
        }
    }

    func favorite(for item: ClipboardItem) -> FavoriteItem? {
        store.favorite(for: item)
    }

    func folderNames(for favoriteID: UUID) -> [String] {
        store.folderNames(for: favoriteID)
    }

    func folderIDs(for favoriteID: UUID) -> [UUID] {
        store.folderIDs(for: favoriteID)
    }

    func search(_ query: String, folderFilter: FavoriteFolderFilter) -> [FavoriteItem] {
        switch folderFilter {
        case .all:
            store.search(query, folderID: nil, sort: selectedSort)
        case .unclassified:
            store.unclassifiedItems(sort: selectedSort).filter { favoriteMatches($0, query: query) }
        case let .folder(folderID):
            store.search(query, folderID: folderID, sort: selectedSort)
        }
    }

    func selectFavorite(_ favorite: FavoriteItem?) {
        selectedFavoriteID = favorite?.id
        draftFavoriteTitle = favorite?.menuTitle ?? ""
    }

    func selectFolderFilter(_ filter: FavoriteFolderFilter) {
        selectedFolderFilter = filter
        switch filter {
        case let .folder(folderID):
            selectedFolderName = folders.first(where: { $0.id == folderID })?.name ?? ""
        case .all, .unclassified:
            selectedFolderName = ""
        }
    }

    func createFolder() {
        do {
            let folder = try store.createFolder(named: newFolderName)
            newFolderName = ""
            selectedFolderFilter = .folder(folder.id)
            selectedFolderName = folder.name
            statusMessage = L10n.tr("settings.favorites.status.folderAdded")
            refreshFromStore()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func renameSelectedFolder(to name: String) {
        guard case let .folder(folderID) = selectedFolderFilter else {
            statusMessage = L10n.tr("settings.favorites.status.selectConcreteFolder")
            return
        }

        do {
            try store.renameFolder(id: folderID, name: name)
            statusMessage = L10n.tr("settings.favorites.status.folderRenamed")
            refreshFromStore()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteSelectedFolder() {
        guard case let .folder(folderID) = selectedFolderFilter else {
            statusMessage = L10n.tr("settings.favorites.status.selectConcreteFolder")
            return
        }

        do {
            try store.deleteFolder(id: folderID)
            selectedFolderFilter = .unclassified
            statusMessage = L10n.tr("settings.favorites.status.folderDeleted")
            refreshFromStore()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func moveSelectedFolder(by offset: Int) {
        guard case let .folder(folderID) = selectedFolderFilter else {
            statusMessage = L10n.tr("settings.favorites.status.selectConcreteFolder")
            return
        }

        do {
            try store.moveFolder(id: folderID, by: offset)
            statusMessage = L10n.tr("settings.favorites.status.folderMoved")
            refreshFromStore()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func updateSelectedFavoriteTitle() {
        guard let favoriteID = selectedFavoriteID else {
            statusMessage = L10n.tr("settings.favorites.status.selectFavorite")
            return
        }

        do {
            try store.updateDisplayTitle(id: favoriteID, title: draftFavoriteTitle)
            statusMessage = L10n.tr("settings.favorites.status.favoriteRenamed")
            refreshFromStore()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func removeSelectedFavorite() {
        guard let favoriteID = selectedFavoriteID else {
            statusMessage = L10n.tr("settings.favorites.status.selectFavorite")
            return
        }

        do {
            try store.removeFavorite(id: favoriteID)
            selectedFavoriteID = nil
            draftFavoriteTitle = ""
            statusMessage = L10n.tr("settings.favorites.status.favoriteRemoved")
            refreshFromStore()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func addSelectedFavorite(to folderID: UUID) {
        guard let favoriteID = selectedFavoriteID else {
            statusMessage = L10n.tr("settings.favorites.status.selectFavorite")
            return
        }

        do {
            try store.addFavorite(id: favoriteID, to: folderID)
            statusMessage = L10n.tr("settings.favorites.status.favoriteAssigned")
            refreshFromStore()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func removeSelectedFavorite(from folderID: UUID) {
        guard let favoriteID = selectedFavoriteID else {
            statusMessage = L10n.tr("settings.favorites.status.selectFavorite")
            return
        }

        do {
            try store.removeFavorite(id: favoriteID, from: folderID)
            statusMessage = L10n.tr("settings.favorites.status.favoriteUnassigned")
            refreshFromStore()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func favoriteMatches(_ favorite: FavoriteItem, query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return true
        }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return favorite.displayTitle.range(of: normalizedQuery, options: options) != nil
            || favorite.contentSnapshot.range(of: normalizedQuery, options: options) != nil
            || favorite.sourceBundleID?.range(of: normalizedQuery, options: options) != nil
    }
}
