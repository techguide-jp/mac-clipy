import AppKit
@testable import MacClipy
import SwiftUI
import XCTest

@MainActor
final class HistoryPopupFocusTests: XCTestCase {
    func testEachPopupPresentationFocusesSearchFieldWithoutClicking() async throws {
        _ = NSApplication.shared
        let popupModel = try makePopupModel()
        let panel = PopupPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 520, height: 460)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: HistoryPopupView(model: popupModel))
        defer {
            panel.orderOut(nil)
        }

        await settleViewUpdates()
        popupModel.prepare(initialMode: .all)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        await settleViewUpdates()

        XCTAssertTrue(panel.firstResponder is NSTextView)

        panel.orderOut(nil)
        XCTAssertTrue(panel.makeFirstResponder(nil))
        popupModel.prepare(initialMode: .all)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        await settleViewUpdates()

        XCTAssertTrue(panel.firstResponder is NSTextView)
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
