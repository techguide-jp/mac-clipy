import Foundation
import Observation

@MainActor
@Observable
final class ClipboardHistoryModel {
    let store: ClipboardStore
    private(set) var items: [ClipboardItem] = []

    init(store: ClipboardStore = ClipboardStore()) {
        self.store = store
    }

    func load() throws {
        try store.load()
        refreshFromStore()
    }

    func refreshFromStore() {
        items = store.items
    }

    func search(_ query: String) -> [ClipboardItem] {
        store.search(query)
    }

    func clear() throws {
        try store.clear()
        refreshFromStore()
    }
}
