import AppKit
import Foundation
import Observation

enum HistoryPopupInitialMode {
    case all
    case favorites
}

struct HistoryPopupResult: Identifiable, Equatable {
    let item: ClipboardItem
    let favorite: FavoriteItem?

    var id: UUID {
        favorite?.id ?? item.id
    }

    var title: String {
        favorite?.menuTitle ?? item.menuTitle
    }

    var detail: String? {
        if let favorite, favorite.hasCustomDisplayTitle {
            favorite.contentMenuTitle
        } else {
            item.sourceBundleID
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
    var isShowingFavoriteNamePrompt = false

    var onChoose: ((ClipboardItem) -> Void)?
    var onClose: (() -> Void)?
    var onSettingsRequested: (() -> Void)?

    init(historyModel: ClipboardHistoryModel, favoritesModel: FavoritesModel) {
        self.historyModel = historyModel
        self.favoritesModel = favoritesModel
    }

    var folders: [FavoriteFolder] {
        favoritesModel.folders
    }

    var results: [HistoryPopupResult] {
        _ = revision

        switch mode {
        case .all:
            return historyModel.search(query).map { item in
                HistoryPopupResult(item: item, favorite: favoritesModel.favorite(for: item))
            }
        case .favorites:
            return favoritesModel.search(query, folderFilter: folderFilter).map { favorite in
                HistoryPopupResult(item: favorite.clipboardItem, favorite: favorite)
            }
        }
    }

    func prepare(initialMode: HistoryPopupInitialMode) {
        query = ""
        mode = initialMode == .favorites ? .favorites : .all
        folderFilter = .all
        selectedRow = 0
        refresh()
    }

    func refresh() {
        historyModel.refreshFromStore()
        favoritesModel.refreshFromStore()
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
        let currentResults = results
        guard currentResults.indices.contains(row) else {
            return
        }

        let result = currentResults[row]
        if let favorite = result.favorite {
            try? favoritesModel.store.markUsed(id: favorite.id)
            favoritesModel.refreshFromStore()
        }

        onChoose?(result.item)
        close()
    }

    func toggleFavoriteForSelectedItem() {
        toggleFavorite(at: selectedRow)
    }

    func toggleFavorite(at row: Int) {
        let currentResults = results
        guard currentResults.indices.contains(row) else {
            return
        }

        do {
            if let favorite = currentResults[row].favorite {
                try favoritesModel.store.removeFavorite(id: favorite.id)
            } else {
                let item = currentResults[row].item
                let title = promptForFavoriteTitle(defaultTitle: FavoriteItem.defaultDisplayTitle(for: item.content))
                guard let title else {
                    return
                }
                try favoritesModel.store.addFavorite(for: item, displayTitle: title)
            }

            refresh()
        } catch {
            NSLog("MacClipy failed to toggle favorite: \(error.localizedDescription)")
        }
    }

    func appendSearchText(_ text: String) {
        query += text
        selectedRow = 0
        refresh()
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
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultTitle : trimmed
    }
}
