import CryptoKit
import Foundation

public struct ClipboardItem: Codable, Equatable, Identifiable {
    public var id: UUID
    public var content: String
    public var sourceBundleID: String?
    public var createdAt: Date
    public var lastUsedAt: Date
    public var useCount: Int
    public var checksum: String

    public init(
        id: UUID = UUID(),
        content: String,
        sourceBundleID: String?,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        useCount: Int = 1,
        checksum: String? = nil
    ) {
        self.id = id
        self.content = content
        self.sourceBundleID = sourceBundleID
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.checksum = checksum ?? Self.makeChecksum(for: content)
    }

    public static func makeChecksum(for content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public var menuTitle: String {
        let collapsed = content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if collapsed.count <= 64 {
            return collapsed.isEmpty ? "(空白のみ)" : collapsed
        }

        let index = collapsed.index(collapsed.startIndex, offsetBy: 64)
        return String(collapsed[..<index]) + "..."
    }
}
