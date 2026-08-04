import AppKit
@testable import MacClipy
import SwiftUI
import XCTest

@MainActor
final class HistoryPopupFocusTests: XCTestCase {
    func testEachPopupPresentationFocusesSearchFieldWithoutClicking() async throws {
        Self.reportProgress("focus test entered")
        _ = NSApplication.shared
        Self.reportProgress("application created")
        let popupModel = try makePopupModel()
        Self.reportProgress("model created")
        let panel = PopupPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 520, height: 460)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        Self.reportProgress("panel created")
        panel.contentView = NSHostingView(rootView: HistoryPopupView(model: popupModel))
        Self.reportProgress("content view installed")
        defer {
            panel.orderOut(nil)
        }

        await settleViewUpdates()
        Self.reportProgress("initial updates settled")
        popupModel.prepare(initialMode: .all)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        Self.reportProgress("first presentation ordered")
        await settleViewUpdates()
        Self.reportProgress("first presentation settled")

        XCTAssertTrue(panel.firstResponder is NSTextView)
        Self.reportProgress("first responder asserted")

        panel.orderOut(nil)
        XCTAssertTrue(panel.makeFirstResponder(nil))
        popupModel.prepare(initialMode: .all)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        Self.reportProgress("second presentation ordered")
        await settleViewUpdates()
        Self.reportProgress("second presentation settled")

        XCTAssertTrue(panel.firstResponder is NSTextView)
        Self.reportProgress("focus test completed")
    }

    private static func reportProgress(_ message: String) {
        FileHandle.standardError.write(Data("[HistoryPopupFocusTests] \(message)\n".utf8))
    }

    private func makePopupModel() throws -> HistoryPopupModel {
        let historyModel = ClipboardHistoryModel(store: ClipboardStore(historyURL: temporaryHistoryURL()))
        try historyModel.store.add(content: "first", sourceBundleID: nil)
        return HistoryPopupModel(
            historyModel: historyModel,
            favoritesModel: FavoritesModel(store: FavoriteStore(favoritesURL: temporaryFavoritesURL()))
        )
    }

    private func settleViewUpdates() async {
        for _ in 0 ..< 3 {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func temporaryHistoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    private func temporaryFavoritesURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("favorites.json")
    }
}
