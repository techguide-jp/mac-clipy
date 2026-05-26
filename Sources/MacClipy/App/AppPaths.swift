import Foundation

public enum AppPaths {
    public static let applicationName = "MacClipy"

    public static var applicationSupportDirectory: URL {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            preconditionFailure("Application Support directory is unavailable")
        }
        return baseURL.appendingPathComponent(applicationName, isDirectory: true)
    }

    public static var historyURL: URL {
        applicationSupportDirectory.appendingPathComponent("history.json")
    }

    public static var settingsURL: URL {
        applicationSupportDirectory.appendingPathComponent("settings.json")
    }

    public static var favoritesURL: URL {
        applicationSupportDirectory.appendingPathComponent("favorites.json")
    }

    public static func ensureParentDirectory(for fileURL: URL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}
