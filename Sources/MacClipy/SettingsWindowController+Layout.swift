import AppKit

extension SettingsWindowController {
    func buildInterface() {
        guard let window else {
            return
        }

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(NSTabViewItem(viewController: NSViewController()))
        tabView.tabViewItem(at: 0).label = L10n.tr("settings.tab.general")
        tabView.tabViewItem(at: 0).view = buildGeneralTab()
        tabView.addTabViewItem(NSTabViewItem(viewController: NSViewController()))
        tabView.tabViewItem(at: 1).label = L10n.tr("settings.tab.excludedApps")
        tabView.tabViewItem(at: 1).view = buildExcludedAppsTab()
        tabView.addTabViewItem(NSTabViewItem(viewController: NSViewController()))
        tabView.tabViewItem(at: 2).label = L10n.tr("settings.tab.favorites")
        tabView.tabViewItem(at: 2).view = buildFavoritesTab()

        let saveButton = NSButton(title: L10n.tr("button.save"), target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: L10n.tr("button.cancel"), target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(tabView)
        contentView.addSubview(statusLabel)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),

            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: cancelButton.leadingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),

            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    func buildGeneralTab() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let historyLabel = sectionLabel("settings.shortcut.title")
        let historyHelpLabel = helpLabel("settings.shortcut.help")
        shortcutRecorder.onMessage = { [weak self] message in self?.statusLabel.stringValue = message }
        shortcutRecorder.translatesAutoresizingMaskIntoConstraints = false

        let resetShortcutButton = NSButton(
            title: L10n.tr("settings.shortcut.reset"),
            target: self,
            action: #selector(resetShortcut)
        )
        resetShortcutButton.bezelStyle = .rounded
        resetShortcutButton.translatesAutoresizingMaskIntoConstraints = false

        let favoriteLabel = sectionLabel("settings.favoriteShortcut.title")
        let favoriteHelpLabel = helpLabel("settings.favoriteShortcut.help")
        favoriteShortcutRecorder.onMessage = { [weak self] message in self?.statusLabel.stringValue = message }
        favoriteShortcutRecorder.translatesAutoresizingMaskIntoConstraints = false

        let resetFavoriteShortcutButton = NSButton(
            title: L10n.tr("settings.shortcut.reset"),
            target: self,
            action: #selector(resetFavoriteShortcut)
        )
        resetFavoriteShortcutButton.bezelStyle = .rounded
        resetFavoriteShortcutButton.translatesAutoresizingMaskIntoConstraints = false

        [historyLabel, historyHelpLabel, shortcutRecorder, resetShortcutButton,
         favoriteLabel, favoriteHelpLabel, favoriteShortcutRecorder, resetFavoriteShortcutButton].forEach(view.addSubview)

        NSLayoutConstraint.activate([
            historyLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            historyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            historyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            historyHelpLabel.topAnchor.constraint(equalTo: historyLabel.bottomAnchor, constant: 4),
            historyHelpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            historyHelpLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            shortcutRecorder.topAnchor.constraint(equalTo: historyHelpLabel.bottomAnchor, constant: 8),
            shortcutRecorder.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            shortcutRecorder.trailingAnchor.constraint(equalTo: resetShortcutButton.leadingAnchor, constant: -10),
            shortcutRecorder.heightAnchor.constraint(equalToConstant: 54),

            resetShortcutButton.centerYAnchor.constraint(equalTo: shortcutRecorder.centerYAnchor),
            resetShortcutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            resetShortcutButton.widthAnchor.constraint(equalToConstant: 110),

            favoriteLabel.topAnchor.constraint(equalTo: shortcutRecorder.bottomAnchor, constant: 22),
            favoriteLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            favoriteLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            favoriteHelpLabel.topAnchor.constraint(equalTo: favoriteLabel.bottomAnchor, constant: 4),
            favoriteHelpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            favoriteHelpLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            favoriteShortcutRecorder.topAnchor.constraint(equalTo: favoriteHelpLabel.bottomAnchor, constant: 8),
            favoriteShortcutRecorder.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            favoriteShortcutRecorder.trailingAnchor.constraint(
                equalTo: resetFavoriteShortcutButton.leadingAnchor,
                constant: -10
            ),
            favoriteShortcutRecorder.heightAnchor.constraint(equalToConstant: 54),

            resetFavoriteShortcutButton.centerYAnchor.constraint(equalTo: favoriteShortcutRecorder.centerYAnchor),
            resetFavoriteShortcutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            resetFavoriteShortcutButton.widthAnchor.constraint(equalToConstant: 110)
        ])

        return view
    }

    func buildExcludedAppsTab() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = sectionLabel("settings.excludedApps.title")
        let excludedAppsHelpLabel = helpLabel("settings.excludedApps.help")
        configureExcludedAppsTable()

        let scrollView = tableScrollView(for: excludedAppsTableView)
        let addButton = actionButton("settings.excludedApps.add", #selector(addExcludedApp))
        let removeButton = actionButton("settings.excludedApps.remove", #selector(removeSelectedExcludedApp))
        let resetButton = actionButton("settings.excludedApps.reset", #selector(resetExcludedApps))

        [titleLabel, excludedAppsHelpLabel, scrollView, addButton, removeButton, resetButton].forEach(view.addSubview)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            excludedAppsHelpLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            excludedAppsHelpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            excludedAppsHelpLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            scrollView.topAnchor.constraint(equalTo: excludedAppsHelpLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -10),

            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            addButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 8),
            removeButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),

            resetButton.leadingAnchor.constraint(equalTo: removeButton.trailingAnchor, constant: 8),
            resetButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            resetButton.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -18)
        ])

        return view
    }

    func buildFavoritesTab() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        configureFavoriteTables()
        configureFavoriteControls()

        let folderScrollView = tableScrollView(for: favoriteFoldersTableView)
        let itemScrollView = tableScrollView(for: favoriteItemsTableView)
        let foldersLabel = sectionLabel("settings.favorites.folders")
        let itemsLabel = sectionLabel("settings.favorites.items")

        let addFolderButton = actionButton("settings.favorites.folder.add", #selector(addFavoriteFolder))
        let renameFolderButton = actionButton("settings.favorites.folder.rename", #selector(renameFavoriteFolder))
        let deleteFolderButton = actionButton("settings.favorites.folder.delete", #selector(deleteFavoriteFolder))
        let moveUpButton = actionButton("settings.favorites.folder.up", #selector(moveFavoriteFolderUp))
        let moveDownButton = actionButton("settings.favorites.folder.down", #selector(moveFavoriteFolderDown))
        let renameItemButton = actionButton("settings.favorites.item.rename", #selector(renameFavoriteItem))
        let removeItemButton = actionButton("settings.favorites.item.remove", #selector(removeFavoriteItem))
        let addToFolderButton = actionButton("settings.favorites.item.addToFolder", #selector(addFavoriteItemToFolder))
        let removeFromFolderButton = actionButton(
            "settings.favorites.item.removeFromFolder",
            #selector(removeFavoriteItemFromFolder)
        )

        let views: [NSView] = [
            foldersLabel, folderScrollView, addFolderButton, renameFolderButton, deleteFolderButton,
            moveUpButton, moveDownButton, itemsLabel, favoriteSortPopup, itemScrollView,
            renameItemButton, removeItemButton, folderAssignmentPopup, addToFolderButton, removeFromFolderButton
        ]
        views.forEach(view.addSubview)

        NSLayoutConstraint.activate([
            foldersLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            foldersLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),

            folderScrollView.topAnchor.constraint(equalTo: foldersLabel.bottomAnchor, constant: 8),
            folderScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            folderScrollView.widthAnchor.constraint(equalToConstant: 210),
            folderScrollView.bottomAnchor.constraint(equalTo: addFolderButton.topAnchor, constant: -10),

            addFolderButton.leadingAnchor.constraint(equalTo: folderScrollView.leadingAnchor),
            addFolderButton.bottomAnchor.constraint(equalTo: moveUpButton.topAnchor, constant: -8),
            renameFolderButton.leadingAnchor.constraint(equalTo: addFolderButton.trailingAnchor, constant: 6),
            renameFolderButton.centerYAnchor.constraint(equalTo: addFolderButton.centerYAnchor),
            deleteFolderButton.leadingAnchor.constraint(equalTo: renameFolderButton.trailingAnchor, constant: 6),
            deleteFolderButton.centerYAnchor.constraint(equalTo: addFolderButton.centerYAnchor),

            moveUpButton.leadingAnchor.constraint(equalTo: folderScrollView.leadingAnchor),
            moveUpButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            moveDownButton.leadingAnchor.constraint(equalTo: moveUpButton.trailingAnchor, constant: 6),
            moveDownButton.centerYAnchor.constraint(equalTo: moveUpButton.centerYAnchor),

            itemsLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            itemsLabel.leadingAnchor.constraint(equalTo: folderScrollView.trailingAnchor, constant: 18),

            favoriteSortPopup.centerYAnchor.constraint(equalTo: itemsLabel.centerYAnchor),
            favoriteSortPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            favoriteSortPopup.widthAnchor.constraint(equalToConstant: 170),

            itemScrollView.topAnchor.constraint(equalTo: itemsLabel.bottomAnchor, constant: 8),
            itemScrollView.leadingAnchor.constraint(equalTo: folderScrollView.trailingAnchor, constant: 18),
            itemScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            itemScrollView.bottomAnchor.constraint(equalTo: renameItemButton.topAnchor, constant: -10),

            renameItemButton.leadingAnchor.constraint(equalTo: itemScrollView.leadingAnchor),
            renameItemButton.bottomAnchor.constraint(equalTo: folderAssignmentPopup.topAnchor, constant: -8),
            removeItemButton.leadingAnchor.constraint(equalTo: renameItemButton.trailingAnchor, constant: 8),
            removeItemButton.centerYAnchor.constraint(equalTo: renameItemButton.centerYAnchor),

            folderAssignmentPopup.leadingAnchor.constraint(equalTo: itemScrollView.leadingAnchor),
            folderAssignmentPopup.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            folderAssignmentPopup.widthAnchor.constraint(equalToConstant: 170),
            addToFolderButton.leadingAnchor.constraint(equalTo: folderAssignmentPopup.trailingAnchor, constant: 8),
            addToFolderButton.centerYAnchor.constraint(equalTo: folderAssignmentPopup.centerYAnchor),
            removeFromFolderButton.leadingAnchor.constraint(equalTo: addToFolderButton.trailingAnchor, constant: 8),
            removeFromFolderButton.centerYAnchor.constraint(equalTo: folderAssignmentPopup.centerYAnchor)
        ])

        return view
    }

    func configureExcludedAppsTable() {
        guard excludedAppsTableView.tableColumns.isEmpty else {
            return
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("excludedApp"))
        column.title = L10n.tr("settings.excludedApps.column")
        column.resizingMask = .autoresizingMask
        excludedAppsTableView.addTableColumn(column)
        excludedAppsTableView.headerView = nil
        excludedAppsTableView.delegate = self
        excludedAppsTableView.dataSource = self
        excludedAppsTableView.rowHeight = 30
        excludedAppsTableView.translatesAutoresizingMaskIntoConstraints = false
    }

    func configureFavoriteTables() {
        if favoriteFoldersTableView.tableColumns.isEmpty {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("favoriteFolder"))
            column.resizingMask = .autoresizingMask
            favoriteFoldersTableView.addTableColumn(column)
            favoriteFoldersTableView.headerView = nil
            favoriteFoldersTableView.delegate = self
            favoriteFoldersTableView.dataSource = self
            favoriteFoldersTableView.rowHeight = 28
            favoriteFoldersTableView.translatesAutoresizingMaskIntoConstraints = false
            favoriteFoldersTableView.action = #selector(favoriteFolderSelectionChanged)
            favoriteFoldersTableView.target = self
        }

        if favoriteItemsTableView.tableColumns.isEmpty {
            let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("favoriteTitle"))
            titleColumn.title = L10n.tr("settings.favorites.column.title")
            titleColumn.width = 250
            favoriteItemsTableView.addTableColumn(titleColumn)

            let foldersColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("favoriteFolders"))
            foldersColumn.title = L10n.tr("settings.favorites.column.folders")
            foldersColumn.width = 170
            favoriteItemsTableView.addTableColumn(foldersColumn)

            favoriteItemsTableView.delegate = self
            favoriteItemsTableView.dataSource = self
            favoriteItemsTableView.rowHeight = 30
            favoriteItemsTableView.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    func configureFavoriteControls() {
        favoriteSortPopup.removeAllItems()
        let sortItems: [(String, FavoriteItemSort)] = [
            (L10n.tr("settings.favorites.sort.manual"), .manual),
            (L10n.tr("settings.favorites.sort.title"), .title),
            (L10n.tr("settings.favorites.sort.lastUsed"), .lastUsed),
            (L10n.tr("settings.favorites.sort.useCount"), .useCount)
        ]
        for item in sortItems {
            favoriteSortPopup.addItem(withTitle: item.0)
            favoriteSortPopup.lastItem?.representedObject = item.1
        }
        favoriteSortPopup.target = self
        favoriteSortPopup.action = #selector(changeFavoriteSort)
        favoriteSortPopup.translatesAutoresizingMaskIntoConstraints = false

        folderAssignmentPopup.target = self
        folderAssignmentPopup.translatesAutoresizingMaskIntoConstraints = false
        reloadFolderAssignmentPopup()
    }

    func reloadFavoriteManagement() {
        reloadFolderAssignmentPopup()
        let selectedFilter = selectedFavoriteFolderFilter()
        let sort = favoriteSortPopup.selectedItem?.representedObject as? FavoriteItemSort ?? .manual

        switch selectedFilter {
        case .all:
            favoriteRows = favoriteStore.search("", folderID: nil, sort: sort)
        case .unclassified:
            favoriteRows = favoriteStore.unclassifiedItems(sort: sort)
        case .folder(let folderID):
            favoriteRows = favoriteStore.search("", folderID: folderID, sort: sort)
        }

        favoriteFoldersTableView.reloadData()
        favoriteItemsTableView.reloadData()
        if favoriteFoldersTableView.selectedRow < 0, favoriteFoldersTableView.numberOfRows > 0 {
            favoriteFoldersTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func reloadFolderAssignmentPopup() {
        folderAssignmentPopup.removeAllItems()
        for folder in favoriteStore.folders {
            folderAssignmentPopup.addItem(withTitle: folder.name)
            folderAssignmentPopup.lastItem?.representedObject = folder.id
        }
        folderAssignmentPopup.isEnabled = !favoriteStore.folders.isEmpty
    }
}
