import Foundation

public struct ClipboardCapturePolicy {
    public let settings: AppSettings
    public let maxItemSize: Int

    public init(settings: AppSettings, maxItemSize: Int = 100 * 1024) {
        self.settings = settings
        self.maxItemSize = maxItemSize
    }

    public func shouldCapture(content: String, sourceBundleID: String?) -> Bool {
        guard !content.isEmpty else {
            return false
        }

        guard Data(content.utf8).count <= maxItemSize else {
            return false
        }

        return !settings.isExcluded(bundleIdentifier: sourceBundleID)
    }
}
