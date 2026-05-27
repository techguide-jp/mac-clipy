import AppKit
import Foundation
import Observation

enum HistoryPopupInitialMode {
    case all
    case favorites
}

struct HistoryPopupResult: Identifiable, Equatable {
    let id: UUID
    let item: ClipboardItem
    let favorite: FavoriteItem?

    static func historyItem(_ item: ClipboardItem, favorite: FavoriteItem?) -> HistoryPopupResult {
        HistoryPopupResult(id: item.id, item: item, favorite: favorite)
    }

    static func favoriteItem(_ favorite: FavoriteItem) -> HistoryPopupResult {
        HistoryPopupResult(id: favorite.id, item: favorite.clipboardItem, favorite: favorite)
    }

    var title: String {
        item.menuTitle
    }

    var detail: String? {
        if let favorite, favorite.hasCustomDisplayTitle {
            favorite.menuTitle
        } else {
            nil
        }
    }
}

@MainActor
@Observable
final class HistoryPopupModel {
    enum Mode: Int, CaseIterable {
        case all
        case favorites
    }

    private let historyModel: ClipboardHistoryModel
    private let favoritesModel: FavoritesModel

    var query = ""
    var mode: Mode = .all
    var folderFilter: FavoriteFolderFilter = .all
    var selectedRow = 0
    var revision = 0
    var presentationRevision = 0
    private(set) var results: [HistoryPopupResult] = []
    var isShowingFavoriteNamePrompt = false

    var onChoose: ((ClipboardItem) -> Void)?
    var onClose: (() -> Void)?
    var onSettingsRequested: (() -> Void)?

    init(historyModel: ClipboardHistoryModel, favoritesModel: FavoritesModel) {
        self.historyModel = historyModel
        self.favoritesModel = favoritesModel
    }

    var folders: [FavoriteFolder] {
        favoritesModel.folders.filter { folder in
            !favoritesModel.search("", folderFilter: .folder(folder.id)).isEmpty
        }
    }

    var showsUnclassifiedFolder: Bool {
        !favoritesModel.search("", folderFilter: .unclassified).isEmpty
    }

    func prepare(initialMode: HistoryPopupInitialMode) {
        query = ""
        mode = initialMode == .favorites ? .favorites : .all
        folderFilter = .all
        selectedRow = 0
        presentationRevision += 1
        refresh()
    }

    func refresh() {
        historyModel.refreshFromStore()
        favoritesModel.refreshFromStore()
        normalizeFolderFilter()
        results = makeResults()
        selectedRow = clampedRow(selectedRow)
        revision += 1
    }

    func close() {
        onClose?()
    }

    func requestSettings() {
        close()
        onSettingsRequested?()
    }

    func selectMode(_ nextMode: Mode) {
        mode = nextMode
        if nextMode == .all {
            folderFilter = .all
        }
        selectedRow = 0
        refresh()
    }

    func selectFolderFilter(_ nextFilter: FavoriteFolderFilter) {
        guard isAvailableFolderFilter(nextFilter) else {
            folderFilter = .all
            mode = .favorites
            selectedRow = 0
            refresh()
            return
        }

        folderFilter = nextFilter
        mode = .favorites
        selectedRow = 0
        refresh()
    }

    func selectFolderByShortcut(_ shortcutIndex: Int) {
        guard folders.indices.contains(shortcutIndex - 1) else {
            return
        }

        selectFolderFilter(.folder(folders[shortcutIndex - 1].id))
    }

    func toggleMode() {
        selectMode(mode == .all ? .favorites : .all)
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else {
            selectedRow = 0
            return
        }

        selectedRow = clampedRow(selectedRow + offset)
    }

    func chooseSelectedItem() {
        chooseItem(at: selectedRow)
    }

    func chooseItem(at row: Int) {
        guard results.indices.contains(row) else {
            return
        }

        choose(results[row], selectedRow: row)
    }

    func chooseItem(id: UUID) {
        guard let row = results.firstIndex(where: { $0.id == id }) else {
            return
        }

        choose(results[row], selectedRow: row)
    }

    func toggleFavoriteForSelectedItem() {
        toggleFavorite(at: selectedRow)
    }

    func toggleFavorite(at row: Int) {
        guard results.indices.contains(row) else {
            return
        }

        toggleFavorite(results[row])
    }

    func toggleFavorite(id: UUID) {
        guard let result = results.first(where: { $0.id == id }) else {
            return
        }

        toggleFavorite(result)
    }

    func appendSearchText(_ text: String) {
        query += text
        selectedRow = 0
        refresh()
    }

    private func normalizeFolderFilter() {
        guard isAvailableFolderFilter(folderFilter) else {
            folderFilter = .all
            return
        }
    }

    private func isAvailableFolderFilter(_ filter: FavoriteFolderFilter) -> Bool {
        switch filter {
        case .all:
            true
        case .unclassified:
            showsUnclassifiedFolder
        case let .folder(folderID):
            folders.contains { $0.id == folderID }
        }
    }

    private func makeResults() -> [HistoryPopupResult] {
        switch mode {
        case .all:
            historyModel.search(query).map { item in
                HistoryPopupResult.historyItem(item, favorite: favoritesModel.favorite(for: item))
            }
        case .favorites:
            favoritesModel.search(query, folderFilter: folderFilter).map { favorite in
                HistoryPopupResult.favoriteItem(favorite)
            }
        }
    }

    private func choose(_ result: HistoryPopupResult, selectedRow row: Int) {
        selectedRow = row
        if let favorite = result.favorite {
            try? favoritesModel.store.markUsed(id: favorite.id)
            favoritesModel.refreshFromStore()
            results = makeResults()
            selectedRow = clampedRow(selectedRow)
            revision += 1
        }

        onChoose?(result.item)
        close()
    }

    private func toggleFavorite(_ result: HistoryPopupResult) {
        do {
            if let favorite = result.favorite {
                try favoritesModel.store.removeFavorite(id: favorite.id)
            } else {
                let title = promptForFavoriteTitle(defaultTitle: FavoriteItem.defaultDisplayTitle(for: result.item.content))
                guard let title else {
                    return
                }
                try favoritesModel.store.addFavorite(for: result.item, displayTitle: title)
            }

            refresh()
        } catch {
            NSLog("MacClipy failed to toggle favorite: \(error.localizedDescription)")
        }
    }

    private func clampedRow(_ row: Int) -> Int {
        guard !results.isEmpty else {
            return 0
        }

        return min(max(row, 0), results.count - 1)
    }

    private func promptForFavoriteTitle(defaultTitle: String) -> String? {
        isShowingFavoriteNamePrompt = true
        defer {
            isShowingFavoriteNamePrompt = false
        }

        let alert = NSAlert()
        alert.messageText = L10n.tr("historyPopup.favoriteName.title")
        alert.informativeText = L10n.tr("historyPopup.favoriteName.message")
        alert.addButton(withTitle: L10n.tr("historyPopup.favoriteName.add"))
        alert.addButton(withTitle: L10n.tr("button.cancel"))

        let textField = NSTextField(string: defaultTitle)
        textField.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        textField.placeholderString = L10n.tr("historyPopup.favoriteName.placeholder")
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultTitle : trimmed
    }
}
