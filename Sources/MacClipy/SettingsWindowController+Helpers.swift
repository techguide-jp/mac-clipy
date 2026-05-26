import AppKit

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onDismiss()
    }
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == excludedAppsTableView {
            return excludedBundleIdentifiers.count
        }
        if tableView == favoriteFoldersTableView {
            return favoriteStore.folders.count + 2
        }
        if tableView == favoriteItemsTableView {
            return favoriteRows.count
        }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == excludedAppsTableView {
            return excludedAppCell(row: row)
        }
        if tableView == favoriteFoldersTableView {
            return favoriteFolderCell(row: row)
        }
        if tableView == favoriteItemsTableView {
            return favoriteItemCell(tableColumn: tableColumn, row: row)
        }
        return nil
    }
}

extension SettingsWindowController {
    func sectionLabel(_ key: String) -> NSTextField {
        let label = NSTextField(labelWithString: L10n.tr(key))
        label.font = .boldSystemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    func helpLabel(_ key: String) -> NSTextField {
        let label = NSTextField(labelWithString: L10n.tr(key))
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    func actionButton(_ key: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: L10n.tr(key), target: self, action: action)
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    func tableScrollView(for tableView: NSTableView) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }

    func presentExcludedAppPanel(_ panel: NSOpenPanel) {
        guard panel.runModal() == .OK else {
            return
        }

        appendExcludedApp(from: panel.url)
    }

    func rollbackSettings(to previousSettings: AppSettings) throws {
        try settingsStore.update(
            excludedBundleIdentifiers: previousSettings.excludedBundleIdentifiers,
            hotKey: previousSettings.hotKey,
            favoriteHotKey: previousSettings.favoriteHotKey
        )
        excludedBundleIdentifiers = previousSettings.excludedBundleIdentifiers
        shortcutRecorder.shortcut = previousSettings.hotKey
        favoriteShortcutRecorder.shortcut = previousSettings.favoriteHotKey
        excludedAppsTableView.reloadData()
    }

    func appendExcludedApp(from appURL: URL?) {
        guard let appURL, let bundle = Bundle(url: appURL), let bundleIdentifier = bundle.bundleIdentifier else {
            statusLabel.stringValue = L10n.tr("settings.status.appReadFailed")
            return
        }

        if excludedBundleIdentifiers.contains(where: { $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame }) {
            statusLabel.stringValue = L10n.tr(
                "settings.status.appAlreadyAdded",
                displayName(for: bundleIdentifier)
            )
            return
        }

        excludedBundleIdentifiers.append(bundleIdentifier)
        excludedBundleIdentifiers = AppSettings.normalizedBundleIdentifiers(excludedBundleIdentifiers)
        excludedAppsTableView.reloadData()
        statusLabel.stringValue = L10n.tr(
            "settings.status.appWillBeExcluded",
            displayName(for: bundleIdentifier)
        )
    }

    func moveSelectedFavoriteFolder(by offset: Int) {
        guard let folder = selectedConcreteFolder() else {
            statusLabel.stringValue = L10n.tr("settings.favorites.status.selectFolder")
            return
        }

        do {
            try favoriteStore.moveFolder(id: folder.id, by: offset)
            reloadFavoriteManagement()
            if let row = row(for: folder.id) {
                favoriteFoldersTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
            statusLabel.stringValue = L10n.tr("settings.favorites.status.folderMoved")
        } catch {
            statusLabel.stringValue = L10n.tr("settings.status.saveFailed", error.localizedDescription)
        }
    }

    func selectedFavoriteFolderFilter() -> FavoriteFolderFilter {
        let selectedRow = favoriteFoldersTableView.selectedRow
        if selectedRow == 1 {
            return .unclassified
        }
        let folderIndex = selectedRow - 2
        guard favoriteStore.folders.indices.contains(folderIndex) else {
            return .all
        }
        return .folder(favoriteStore.folders[folderIndex].id)
    }

    func selectedConcreteFolder() -> FavoriteFolder? {
        guard case .folder(let folderID) = selectedFavoriteFolderFilter() else {
            return nil
        }
        return favoriteStore.folders.first { $0.id == folderID }
    }

    func selectedFavoriteItem() -> FavoriteItem? {
        let selectedRow = favoriteItemsTableView.selectedRow
        guard favoriteRows.indices.contains(selectedRow) else {
            return nil
        }
        return favoriteRows[selectedRow]
    }

    func row(for folderID: UUID) -> Int? {
        guard let folderIndex = favoriteStore.folders.firstIndex(where: { $0.id == folderID }) else {
            return nil
        }
        return folderIndex + 2
    }
}
