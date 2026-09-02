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
    case duplicateFavorite
    case favoriteNotFound
    case folderNotFound

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            L10n.tr("favorites.error.emptyName")
        case .emptyContent:
            L10n.tr("favorites.error.emptyContent")
        case .duplicateFavorite:
            L10n.tr("favorites.error.duplicateFavorite")
        case .favoriteNotFound:
            L10n.tr("favorites.error.favoriteNotFound")
        case .folderNotFound:
            L10n.tr("favorites.error.folderNotFound")
        }
    }
}

public struct FavoriteItem: Codable, Equatable, Identifiable {
    public var id: UUID
    public var clipboardItemID: UUID?
    public var checksum: String
    // 履歴上限で消えないよう、貼り付け用の正本をお気に入り側に保持する。
    public var contentSnapshot: String
    public var sourceBundleID: String?
    public var displayTitle: String
    public var favoritedAt: Date
    public var lastUsedAt: Date
    public var useCount: Int
    public var sortOrder: Int
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        clipboardItemID: UUID?,
        checksum: String,
        contentSnapshot: String,
        sourceBundleID: String?,
        displayTitle: String,
        favoritedAt: Date,
        lastUsedAt: Date,
        useCount: Int,
        sortOrder: Int,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.clipboardItemID = clipboardItemID
        self.checksum = checksum
        self.contentSnapshot = contentSnapshot
        self.sourceBundleID = sourceBundleID
        self.displayTitle = displayTitle
        self.favoritedAt = favoritedAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.sortOrder = sortOrder
        self.deletedAt = deletedAt
    }

    public var menuTitle: String {
        let title = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? Self.defaultDisplayTitle(for: contentSnapshot) : title
    }

    public var contentMenuTitle: String {
        Self.defaultDisplayTitle(for: contentSnapshot)
    }

    public var hasCustomDisplayTitle: Bool {
        menuTitle != contentMenuTitle
    }

    public var clipboardItem: ClipboardItem {
        ClipboardItem(
            id: clipboardItemID ?? id,
            content: contentSnapshot,
            sourceBundleID: sourceBundleID,
            createdAt: favoritedAt,
            lastUsedAt: lastUsedAt,
            useCount: useCount,
            checksum: checksum
        )
    }

    public static func defaultDisplayTitle(for content: String) -> String {
        let collapsed = content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if collapsed.count <= AppConstants.Clipboard.menuTitleCharacterLimit {
            return collapsed.isEmpty ? L10n.tr("clipboard.emptyWhitespace") : collapsed
        }

        let index = collapsed.index(collapsed.startIndex, offsetBy: AppConstants.Clipboard.menuTitleCharacterLimit)
        return String(collapsed[..<index]) + "..."
    }
}

public struct FavoriteFolder: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

public struct FavoriteFolderMembership: Codable, Equatable, Identifiable {
    public var id: UUID
    public var favoriteItemID: UUID
    public var folderID: UUID
    public var createdAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        favoriteItemID: UUID,
        folderID: UUID,
        createdAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.favoriteItemID = favoriteItemID
        self.folderID = folderID
        self.createdAt = createdAt
        self.deletedAt = deletedAt
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
