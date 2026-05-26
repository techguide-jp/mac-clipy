import Foundation

public struct AppSettings: Codable, Equatable {
    public static let defaultExcludedBundleIdentifiers = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.apple.keychainaccess",
        "com.local.MacClipy"
    ]

    public var excludedBundleIdentifiers: [String]
    public var hotKey: KeyboardShortcut
    public var favoriteHotKey: KeyboardShortcut

    public init(
        excludedBundleIdentifiers: [String] = Self.defaultExcludedBundleIdentifiers,
        hotKey: KeyboardShortcut = .defaultShortcut,
        favoriteHotKey: KeyboardShortcut = .defaultFavoriteShortcut
    ) {
        self.excludedBundleIdentifiers = Self.normalizedBundleIdentifiers(excludedBundleIdentifiers)
        self.hotKey = hotKey
        self.favoriteHotKey = favoriteHotKey
    }

    private enum CodingKeys: String, CodingKey {
        case excludedBundleIdentifiers
        case hotKey
        case favoriteHotKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let identifiers = try container.decodeIfPresent([String].self, forKey: .excludedBundleIdentifiers)
            ?? Self.defaultExcludedBundleIdentifiers

        let decodedHotKey = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .hotKey) ?? .defaultShortcut
        let decodedFavoriteHotKey = try container.decodeIfPresent(
            KeyboardShortcut.self,
            forKey: .favoriteHotKey
        ) ?? .defaultFavoriteShortcut

        self.excludedBundleIdentifiers = Self.normalizedBundleIdentifiers(identifiers)
        self.hotKey = decodedHotKey.isRegisterable ? decodedHotKey : .defaultShortcut
        self.favoriteHotKey = decodedFavoriteHotKey.isRegisterable
            ? decodedFavoriteHotKey
            : .defaultFavoriteShortcut
    }

    public func isExcluded(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else {
            return false
        }

        return excludedBundleIdentifiers.contains {
            $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
    }

    public static func normalizedBundleIdentifiers(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for identifier in identifiers {
            let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            normalized.append(trimmed)
        }

        return normalized
    }
}

public final class SettingsStore {
    public private(set) var settings: AppSettings
    public let settingsURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(settingsURL: URL = AppPaths.settingsURL) {
        self.settingsURL = settingsURL
        self.settings = AppSettings()

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
    }

    public func load() throws {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            settings = AppSettings()
            try save()
            return
        }

        let data = try Data(contentsOf: settingsURL)
        guard !data.isEmpty else {
            settings = AppSettings()
            try save()
            return
        }

        settings = try decoder.decode(AppSettings.self, from: data)
    }

    public func save() throws {
        try AppPaths.ensureParentDirectory(for: settingsURL)
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    public func updateExcludedBundleIdentifiers(_ identifiers: [String]) throws {
        settings.excludedBundleIdentifiers = AppSettings.normalizedBundleIdentifiers(identifiers)
        try save()
    }

    public func update(
        excludedBundleIdentifiers identifiers: [String],
        hotKey: KeyboardShortcut,
        favoriteHotKey: KeyboardShortcut
    ) throws {
        settings.excludedBundleIdentifiers = AppSettings.normalizedBundleIdentifiers(identifiers)
        settings.hotKey = hotKey.isRegisterable ? hotKey : .defaultShortcut
        settings.favoriteHotKey = favoriteHotKey.isRegisterable ? favoriteHotKey : .defaultFavoriteShortcut
        try save()
    }
}
