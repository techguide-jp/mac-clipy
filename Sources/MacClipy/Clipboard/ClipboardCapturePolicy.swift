import Foundation

public struct ClipboardCapturePolicy {
    public let excludedBundleIdentifiers: [String]
    public let maxItemSize: Int

    public init(
        excludedBundleIdentifiers: [String],
        maxItemSize: Int = AppConstants.Clipboard.defaultMaxItemSizeBytes
    ) {
        self.excludedBundleIdentifiers = SettingsDefaults.normalizedBundleIdentifiers(excludedBundleIdentifiers)
        self.maxItemSize = maxItemSize
    }

    public func shouldCapture(content: String, sourceBundleID: String?) -> Bool {
        guard !content.isEmpty else {
            return false
        }

        guard Data(content.utf8).count <= maxItemSize else {
            return false
        }

        return !SettingsDefaults.isExcluded(
            bundleIdentifier: sourceBundleID,
            in: excludedBundleIdentifiers
        )
    }
}
