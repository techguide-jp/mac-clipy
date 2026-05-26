import XCTest
@testable import MacClipy

final class ClipboardStoreTests: XCTestCase {
    func testDuplicateTextUpdatesExistingItem() throws {
        let store = makeStore()
        let first = try XCTUnwrap(
            try store.add(content: "hello", sourceBundleID: "app.one", at: Date(timeIntervalSince1970: 10))
        )
        let second = try XCTUnwrap(
            try store.add(content: "hello", sourceBundleID: "app.two", at: Date(timeIntervalSince1970: 20))
        )

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(store.items[0].useCount, 2)
        XCTAssertEqual(store.items[0].sourceBundleID, "app.two")
        XCTAssertEqual(store.items[0].lastUsedAt, Date(timeIntervalSince1970: 20))
    }

    func testMaxItemsTrimsOldEntries() throws {
        let store = makeStore(maxItems: 3)

        for index in 0..<5 {
            try store.add(content: "item-\(index)",
                          sourceBundleID: nil,
                          at: Date(timeIntervalSince1970: TimeInterval(index)))
        }

        XCTAssertEqual(store.items.map(\.content), ["item-4", "item-3", "item-2"])
    }

    func testSearchIsCaseInsensitive() throws {
        let store = makeStore()
        try store.add(content: "Hello Clipboard", sourceBundleID: nil)
        try store.add(content: "Another item", sourceBundleID: nil)

        XCTAssertEqual(store.search("clipboard").map(\.content), ["Hello Clipboard"])
        XCTAssertEqual(store.search("HELLO").map(\.content), ["Hello Clipboard"])
    }

    func testSearchSupportsLargeHistory() throws {
        let store = makeStore(maxItems: 200)

        for index in 0..<100 {
            try store.add(content: "project note \(index)",
                          sourceBundleID: "com.example.Editor",
                          at: Date(timeIntervalSince1970: TimeInterval(index)))
        }

        XCTAssertEqual(store.search("").count, 100)
        XCTAssertEqual(store.search("note 9").map(\.content), [
            "project note 99",
            "project note 98",
            "project note 97",
            "project note 96",
            "project note 95",
            "project note 94",
            "project note 93",
            "project note 92",
            "project note 91",
            "project note 90",
            "project note 9"
        ])
    }

    func testExcludedBundleIdentifierIsNotCaptured() {
        let policy = ClipboardCapturePolicy(excludedBundleIdentifiers: ["com.example.SecretApp"])

        XCTAssertFalse(policy.shouldCapture(content: "secret", sourceBundleID: "com.example.SecretApp"))
        XCTAssertTrue(policy.shouldCapture(content: "normal", sourceBundleID: "com.example.Notes"))
    }

    func testJSONPersistenceRoundTrip() throws {
        let historyURL = temporaryHistoryURL()
        let store = ClipboardStore(historyURL: historyURL)
        try store.add(content: "persisted", sourceBundleID: "com.example.Source", at: Date(timeIntervalSince1970: 100))

        let restoredStore = ClipboardStore(historyURL: historyURL)
        try restoredStore.load()

        XCTAssertEqual(restoredStore.items.count, 1)
        XCTAssertEqual(restoredStore.items[0].content, "persisted")
        XCTAssertEqual(restoredStore.items[0].sourceBundleID, "com.example.Source")
        XCTAssertEqual(restoredStore.items[0].createdAt, Date(timeIntervalSince1970: 100))
    }

    private func makeStore(maxItems: Int = 200, maxItemSize: Int = 100 * 1024) -> ClipboardStore {
        ClipboardStore(historyURL: temporaryHistoryURL(), maxItems: maxItems, maxItemSize: maxItemSize)
    }

    private func temporaryHistoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("history.json")
    }
}
