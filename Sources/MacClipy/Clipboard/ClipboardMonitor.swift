import AppKit
import Foundation

@MainActor
public final class ClipboardMonitor {
    public private(set) var isPaused = false

    private let pasteboard: NSPasteboard
    private let store: ClipboardStore
    private let excludedBundleIdentifiers: () -> [String]
    private let onChange: () -> Void

    private var timer: Timer?
    private var lastChangeCount: Int

    public init(
        store: ClipboardStore,
        excludedBundleIdentifiers: @escaping () -> [String],
        pasteboard: NSPasteboard = .general,
        onChange: @escaping () -> Void
    ) {
        self.store = store
        self.excludedBundleIdentifiers = excludedBundleIdentifiers
        self.pasteboard = pasteboard
        self.onChange = onChange
        lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        stop()
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.ClipboardMonitor.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    @discardableResult
    public func copyToPasteboard(_ item: ClipboardItem) throws -> ClipboardItem {
        let updatedItem = try store.markUsed(id: item.id) ?? item
        writeToPasteboard(updatedItem.content)
        onChange()
        return updatedItem
    }

    public func copyTextToPasteboard(_ content: String) {
        writeToPasteboard(content)
    }

    @discardableResult
    public func captureCurrentPasteboardIfNeeded(sourceBundleID: String?) -> Bool {
        poll(sourceBundleID: sourceBundleID)
    }

    @discardableResult
    private func poll() -> Bool {
        poll(sourceBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    @discardableResult
    private func poll(sourceBundleID: String?) -> Bool {
        guard !isPaused else {
            return false
        }

        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else {
            return false
        }

        lastChangeCount = changeCount

        guard let content = pasteboard.string(forType: .string) else {
            return false
        }

        let policy = ClipboardCapturePolicy(
            excludedBundleIdentifiers: excludedBundleIdentifiers(),
            maxItemSize: store.maxItemSize
        )
        guard policy.shouldCapture(content: content, sourceBundleID: sourceBundleID) else {
            return false
        }

        do {
            if try store.add(content: content, sourceBundleID: sourceBundleID) != nil {
                onChange()
                return true
            }
        } catch {
            NSLog("MacClipy failed to store clipboard item: \(error.localizedDescription)")
        }

        return false
    }

    private func writeToPasteboard(_ content: String) {
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }
}
