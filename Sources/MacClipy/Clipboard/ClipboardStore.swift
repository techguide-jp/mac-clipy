import Foundation

public final class ClipboardStore {
    public private(set) var items: [ClipboardItem]
    public let historyURL: URL
    public let maxItems: Int
    public let maxItemSize: Int

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        historyURL: URL = AppPaths.historyURL,
        maxItems: Int = 200,
        maxItemSize: Int = 100 * 1024
    ) {
        self.historyURL = historyURL
        self.maxItems = maxItems
        self.maxItemSize = maxItemSize
        self.items = []

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws {
        guard FileManager.default.fileExists(atPath: historyURL.path) else {
            items = []
            return
        }

        let data = try Data(contentsOf: historyURL)
        guard !data.isEmpty else {
            items = []
            return
        }

        items = try decoder.decode([ClipboardItem].self, from: data)
        trimToLimit()
    }

    public func save() throws {
        try AppPaths.ensureParentDirectory(for: historyURL)
        let data = try encoder.encode(items)
        try data.write(to: historyURL, options: .atomic)
    }

    @discardableResult
    public func add(content: String, sourceBundleID: String?, at date: Date = Date()) throws -> ClipboardItem? {
        guard shouldStore(content: content) else {
            return nil
        }

        let checksum = ClipboardItem.makeChecksum(for: content)
        if let existingIndex = items.firstIndex(where: { $0.checksum == checksum && $0.content == content }) {
            var item = items.remove(at: existingIndex)
            item.sourceBundleID = sourceBundleID ?? item.sourceBundleID
            item.lastUsedAt = date
            item.useCount += 1
            items.insert(item, at: 0)
            try save()
            return item
        }

        let item = ClipboardItem(
            content: content,
            sourceBundleID: sourceBundleID,
            createdAt: date,
            lastUsedAt: date,
            useCount: 1,
            checksum: checksum
        )

        items.insert(item, at: 0)
        trimToLimit()
        try save()
        return item
    }

    @discardableResult
    public func markUsed(id: UUID, at date: Date = Date()) throws -> ClipboardItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        var item = items.remove(at: index)
        item.lastUsedAt = date
        item.useCount += 1
        items.insert(item, at: 0)
        try save()
        return item
    }

    public func search(_ query: String) -> [ClipboardItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return items
        }

        return items.filter { item in
            let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            return item.content.range(of: normalizedQuery, options: options) != nil
                || item.sourceBundleID?.range(of: normalizedQuery, options: options) != nil
        }
    }

    public func clear() throws {
        items.removeAll()
        try save()
    }

    public func delete(id: UUID) throws {
        items.removeAll { $0.id == id }
        try save()
    }

    private func shouldStore(content: String) -> Bool {
        guard !content.isEmpty else {
            return false
        }

        return Data(content.utf8).count <= maxItemSize
    }

    private func trimToLimit() {
        guard items.count > maxItems else {
            return
        }

        items.removeSubrange(maxItems..<items.count)
    }
}
