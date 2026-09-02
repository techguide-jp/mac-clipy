import Foundation

public final class FavoriteStore {
    public private(set) var data: FavoriteData
    public let favoritesURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(favoritesURL: URL = AppPaths.favoritesURL) {
        self.favoritesURL = favoritesURL
        data = FavoriteData()

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public var items: [FavoriteItem] {
        data.items.filter { $0.deletedAt == nil }
    }

    public var folders: [FavoriteFolder] {
        data.folders
            .filter { $0.deletedAt == nil }
            .sorted { left, right in
                if left.sortOrder == right.sortOrder {
                    return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
                }
                return left.sortOrder < right.sortOrder
            }
    }

    public var memberships: [FavoriteFolderMembership] {
        data.memberships.filter { $0.deletedAt == nil }
    }

    public func load() throws {
        guard FileManager.default.fileExists(atPath: favoritesURL.path) else {
            data = FavoriteData()
            return
        }

        let fileData = try Data(contentsOf: favoritesURL)
        guard !fileData.isEmpty else {
            data = FavoriteData()
            return
        }

        data = try decoder.decode(FavoriteData.self, from: fileData)
        normalizeSortOrders()
    }

    public func save() throws {
        try AppPaths.ensureParentDirectory(for: favoritesURL)
        let fileData = try encoder.encode(data)
        try fileData.write(to: favoritesURL, options: .atomic)
    }

    public func favorite(for item: ClipboardItem) -> FavoriteItem? {
        // 履歴側のIDが変わっても同じ内容は同一のお気に入りとして扱う。
        items.first {
            $0.checksum == item.checksum && $0.contentSnapshot == item.content
        }
    }

    public func isFavorite(_ item: ClipboardItem) -> Bool {
        favorite(for: item) != nil
    }

    @discardableResult
    public func toggleFavorite(for item: ClipboardItem, at date: Date = Date()) throws -> Bool {
        if let favorite = favorite(for: item) {
            try removeFavorite(id: favorite.id)
            return false
        }

        try addFavorite(for: item, at: date)
        return true
    }

    @discardableResult
    public func addFavorite(
        for item: ClipboardItem,
        displayTitle: String? = nil,
        at date: Date = Date()
    ) throws -> FavoriteItem {
        if let existing = favorite(for: item) {
            return existing
        }

        let resolvedDisplayTitle = resolvedDisplayTitle(for: item.content, displayTitle: displayTitle)
        let favorite = FavoriteItem(
            clipboardItemID: item.id,
            checksum: item.checksum,
            contentSnapshot: item.content,
            sourceBundleID: item.sourceBundleID,
            displayTitle: resolvedDisplayTitle,
            favoritedAt: date,
            lastUsedAt: item.lastUsedAt,
            useCount: item.useCount,
            sortOrder: nextSortOrder(for: data.items)
        )
        data.items.append(favorite)
        try save()
        return favorite
    }

    @discardableResult
    public func addManualFavorite(
        content: String,
        displayTitle: String? = nil,
        at date: Date = Date()
    ) throws -> FavoriteItem {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FavoriteStoreError.emptyContent
        }

        let checksum = ClipboardItem.makeChecksum(for: content)
        if let existing = items.first(where: { $0.checksum == checksum && $0.contentSnapshot == content }) {
            return existing
        }

        let favorite = FavoriteItem(
            clipboardItemID: nil,
            checksum: checksum,
            contentSnapshot: content,
            sourceBundleID: nil,
            displayTitle: resolvedDisplayTitle(for: content, displayTitle: displayTitle),
            favoritedAt: date,
            lastUsedAt: date,
            useCount: AppConstants.Clipboard.initialUseCount,
            sortOrder: nextSortOrder(for: data.items)
        )
        data.items.append(favorite)
        try save()
        return favorite
    }

    public func removeFavorite(id: UUID) throws {
        guard let index = data.items.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
            throw FavoriteStoreError.favoriteNotFound
        }

        data.items[index].deletedAt = Date()
        for membershipIndex in data.memberships.indices where data.memberships[membershipIndex].favoriteItemID == id {
            data.memberships[membershipIndex].deletedAt = Date()
        }
        try save()
    }

    public func markUsed(id: UUID, at date: Date = Date()) throws {
        guard let index = data.items.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
            throw FavoriteStoreError.favoriteNotFound
        }

        data.items[index].lastUsedAt = date
        data.items[index].useCount += AppConstants.Clipboard.useCountIncrement
        try save()
    }

    public func updateDisplayTitle(id: UUID, title: String) throws {
        guard let favorite = items.first(where: { $0.id == id }) else {
            throw FavoriteStoreError.favoriteNotFound
        }

        try updateFavorite(id: id, displayTitle: title, content: favorite.contentSnapshot)
    }

    public func updateFavorite(id: UUID, displayTitle: String, content: String) throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FavoriteStoreError.emptyContent
        }
        guard let index = data.items.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
            throw FavoriteStoreError.favoriteNotFound
        }

        let checksum = ClipboardItem.makeChecksum(for: content)
        guard !items.contains(where: {
            $0.id != id && $0.checksum == checksum && $0.contentSnapshot == content
        }) else {
            throw FavoriteStoreError.duplicateFavorite
        }

        if data.items[index].contentSnapshot != content {
            data.items[index].contentSnapshot = content
            data.items[index].checksum = checksum
            data.items[index].clipboardItemID = nil
            data.items[index].sourceBundleID = nil
        }
        data.items[index].displayTitle = resolvedDisplayTitle(for: content, displayTitle: displayTitle)
        try save()
    }

    @discardableResult
    public func createFolder(named name: String, at date: Date = Date()) throws -> FavoriteFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FavoriteStoreError.emptyName
        }

        let folder = FavoriteFolder(
            name: trimmed,
            sortOrder: nextSortOrder(for: data.folders),
            createdAt: date,
            updatedAt: date
        )
        data.folders.append(folder)
        try save()
        return folder
    }

    public func renameFolder(id: UUID, name: String, at date: Date = Date()) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FavoriteStoreError.emptyName
        }

        guard let index = data.folders.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
            throw FavoriteStoreError.folderNotFound
        }

        data.folders[index].name = trimmed
        data.folders[index].updatedAt = date
        try save()
    }

    public func deleteFolder(id: UUID, at date: Date = Date()) throws {
        guard let index = data.folders.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
            throw FavoriteStoreError.folderNotFound
        }

        data.folders[index].deletedAt = date
        // フォルダ削除ではお気に入り本体を消さず、所属だけ外して未分類として残す。
        for membershipIndex in data.memberships.indices where data.memberships[membershipIndex].folderID == id {
            data.memberships[membershipIndex].deletedAt = date
        }
        try save()
    }

    public func moveFolder(id: UUID, by offset: Int) throws {
        let sorted = folders
        guard let currentIndex = sorted.firstIndex(where: { $0.id == id }) else {
            throw FavoriteStoreError.folderNotFound
        }

        let nextIndex = min(max(currentIndex + offset, 0), sorted.count - 1)
        guard nextIndex != currentIndex else {
            return
        }

        let currentFolder = sorted[currentIndex]
        let nextFolder = sorted[nextIndex]
        guard let currentDataIndex = data.folders.firstIndex(where: { $0.id == currentFolder.id }),
              let nextDataIndex = data.folders.firstIndex(where: { $0.id == nextFolder.id })
        else {
            throw FavoriteStoreError.folderNotFound
        }

        let currentSortOrder = data.folders[currentDataIndex].sortOrder
        data.folders[currentDataIndex].sortOrder = data.folders[nextDataIndex].sortOrder
        data.folders[nextDataIndex].sortOrder = currentSortOrder
        try save()
    }

    public func addFavorite(id favoriteID: UUID, to folderID: UUID, at date: Date = Date()) throws {
        guard items.contains(where: { $0.id == favoriteID }) else {
            throw FavoriteStoreError.favoriteNotFound
        }
        guard folders.contains(where: { $0.id == folderID }) else {
            throw FavoriteStoreError.folderNotFound
        }
        // 複数フォルダ所属は許可するが、同じフォルダへの重複所属は作らない。
        guard !memberships.contains(where: { $0.favoriteItemID == favoriteID && $0.folderID == folderID }) else {
            return
        }

        data.memberships.append(
            FavoriteFolderMembership(favoriteItemID: favoriteID, folderID: folderID, createdAt: date)
        )
        try save()
    }

    public func removeFavorite(id favoriteID: UUID, from folderID: UUID, at date: Date = Date()) throws {
        var removed = false
        for index in data.memberships.indices
            where data.memberships[index].favoriteItemID == favoriteID
            && data.memberships[index].folderID == folderID
            && data.memberships[index].deletedAt == nil {
            data.memberships[index].deletedAt = date
            removed = true
        }

        if removed {
            try save()
        }
    }

    public func folderIDs(for favoriteID: UUID) -> [UUID] {
        memberships
            .filter { $0.favoriteItemID == favoriteID }
            .map(\.folderID)
    }

    public func folderNames(for favoriteID: UUID) -> [String] {
        let folderMap = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0.name) })
        return folderIDs(for: favoriteID).compactMap { folderMap[$0] }.sorted()
    }

    public func search(_ query: String, folderID: UUID?, sort: FavoriteItemSort = .manual) -> [FavoriteItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let scopedItems = items.filter { item in
            guard let folderID else {
                return true
            }
            return memberships.contains { $0.favoriteItemID == item.id && $0.folderID == folderID }
        }
        let queriedItems = scopedItems.filter { item in
            guard !normalizedQuery.isEmpty else {
                return true
            }

            let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            return item.displayTitle.range(of: normalizedQuery, options: options) != nil
                || item.contentSnapshot.range(of: normalizedQuery, options: options) != nil
                || item.sourceBundleID?.range(of: normalizedQuery, options: options) != nil
        }

        return sortItems(queriedItems, by: sort)
    }

    public func unclassifiedItems(sort: FavoriteItemSort = .manual) -> [FavoriteItem] {
        let classifiedIDs = Set(memberships.map(\.favoriteItemID))
        return sortItems(items.filter { !classifiedIDs.contains($0.id) }, by: sort)
    }

    public func clear() throws {
        data = FavoriteData()
        try save()
    }

    private func sortItems(_ items: [FavoriteItem], by sort: FavoriteItemSort) -> [FavoriteItem] {
        switch sort {
        case .manual:
            items.sorted { left, right in
                if left.sortOrder == right.sortOrder {
                    return left.favoritedAt > right.favoritedAt
                }
                return left.sortOrder < right.sortOrder
            }
        case .title:
            items.sorted { $0.menuTitle.localizedCaseInsensitiveCompare($1.menuTitle) == .orderedAscending }
        case .lastUsed:
            items.sorted { $0.lastUsedAt > $1.lastUsedAt }
        case .useCount:
            items.sorted { left, right in
                if left.useCount == right.useCount {
                    return left.lastUsedAt > right.lastUsedAt
                }
                return left.useCount > right.useCount
            }
        }
    }

    private func normalizeSortOrders() {
        let sortedItems = data.items.sorted { $0.sortOrder < $1.sortOrder }
        for (offset, item) in sortedItems.enumerated() {
            if let index = data.items.firstIndex(where: { $0.id == item.id }) {
                data.items[index].sortOrder = offset
            }
        }

        let sortedFolders = data.folders.sorted { $0.sortOrder < $1.sortOrder }
        for (offset, folder) in sortedFolders.enumerated() {
            if let index = data.folders.firstIndex(where: { $0.id == folder.id }) {
                data.folders[index].sortOrder = offset
            }
        }
    }
}
