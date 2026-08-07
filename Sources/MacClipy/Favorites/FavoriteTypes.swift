import Foundation

public enum FavoriteItemSort: String, CaseIterable, Equatable, Hashable {
    case manual
    case title
    case lastUsed
    case useCount
}

public enum FavoriteStoreError: LocalizedError, Equatable {
    case emptyName
    case emptyContent
    case favoriteNotFound
    case folderNotFound

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            L10n.tr("favorites.error.emptyName")
        case .emptyContent:
            L10n.tr("favorites.error.emptyContent")
        case .favoriteNotFound:
            L10n.tr("favorites.error.favoriteNotFound")
        case .folderNotFound:
            L10n.tr("favorites.error.folderNotFound")
        }
    }
}

public struct FavoriteData: Codable, Equatable {
    public var items: [FavoriteItem]
    public var folders: [FavoriteFolder]
    public var memberships: [FavoriteFolderMembership]

    public init(
        items: [FavoriteItem] = [],
        folders: [FavoriteFolder] = [],
        memberships: [FavoriteFolderMembership] = []
    ) {
        self.items = items
        self.folders = folders
        self.memberships = memberships
    }
}
