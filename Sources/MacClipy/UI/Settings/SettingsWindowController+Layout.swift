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

        configureFavoriteTables()
        configureFavoriteControls()

        let folderScrollView = tableScrollView(for: favoriteFoldersTableView)
        let itemScrollView = tableScrollView(for: favoriteItemsTableView)
        let foldersLabel = sectionLabel("settings.favorites.folders")
        let itemsLabel = sectionLabel("settings.favorites.items")

        let folderToolbar = toolbarStack([
            iconButton("settings.favorites.folder.add", symbolName: "plus", action: #selector(addFavoriteFolder)),
            iconButton("settings.favorites.folder.rename", symbolName: "pencil", action: #selector(renameFavoriteFolder)),
            iconButton("settings.favorites.folder.delete", symbolName: "trash", action: #selector(deleteFavoriteFolder)),
            iconButton("settings.favorites.folder.up", symbolName: "chevron.up", action: #selector(moveFavoriteFolderUp)),
            iconButton("settings.favorites.folder.down", symbolName: "chevron.down", action: #selector(moveFavoriteFolderDown))
        ])

        let itemToolbarSpacer = NSView()
        itemToolbarSpacer.translatesAutoresizingMaskIntoConstraints = false
        itemToolbarSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        itemToolbarSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let itemToolbar = toolbarStack(
            [
                iconButton(
                    "settings.favorites.item.rename",
                    symbolName: "pencil",
                    action: #selector(renameFavoriteItem)
                ),
                iconButton(
                    "settings.favorites.item.remove",
                    symbolName: "star.slash",
                    action: #selector(removeFavoriteItem)
                ),
                itemToolbarSpacer,
                folderAssignmentPopup,
                iconButton(
                    "settings.favorites.item.addToFolder",
                    symbolName: "folder.badge.plus",
                    action: #selector(addFavoriteItemToFolder)
                ),
                iconButton(
                    "settings.favorites.item.removeFromFolder",
                    symbolName: "folder.badge.minus",
                    action: #selector(removeFavoriteItemFromFolder)
                )
            ],
            spacing: 8
        )
        itemToolbar.setCustomSpacing(14, after: itemToolbarSpacer)

        let views: [NSView] = [
            foldersLabel, folderScrollView, folderToolbar, itemsLabel, favoriteSortPopup, itemScrollView, itemToolbar
        ]
        views.forEach(view.addSubview)

        NSLayoutConstraint.activate([
            foldersLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            foldersLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),

            folderScrollView.topAnchor.constraint(equalTo: foldersLabel.bottomAnchor, constant: 8),
            folderScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            folderScrollView.widthAnchor.constraint(equalToConstant: 220),
            folderScrollView.bottomAnchor.constraint(equalTo: folderToolbar.topAnchor, constant: -8),

            folderToolbar.leadingAnchor.constraint(equalTo: folderScrollView.leadingAnchor),
            folderToolbar.trailingAnchor.constraint(lessThanOrEqualTo: folderScrollView.trailingAnchor),
            folderToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            folderToolbar.heightAnchor.constraint(equalToConstant: 32),

            itemsLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            itemsLabel.leadingAnchor.constraint(equalTo: folderScrollView.trailingAnchor, constant: 20),

            favoriteSortPopup.centerYAnchor.constraint(equalTo: itemsLabel.centerYAnchor),
            favoriteSortPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            favoriteSortPopup.widthAnchor.constraint(equalToConstant: 180),
            itemsLabel.trailingAnchor.constraint(lessThanOrEqualTo: favoriteSortPopup.leadingAnchor, constant: -12),

            itemScrollView.topAnchor.constraint(equalTo: itemsLabel.bottomAnchor, constant: 8),
            itemScrollView.leadingAnchor.constraint(equalTo: itemsLabel.leadingAnchor),
            itemScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            itemScrollView.bottomAnchor.constraint(equalTo: itemToolbar.topAnchor, constant: -8),

            itemToolbar.leadingAnchor.constraint(equalTo: itemScrollView.leadingAnchor),
            itemToolbar.trailingAnchor.constraint(equalTo: itemScrollView.trailingAnchor),
            itemToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            itemToolbar.heightAnchor.constraint(equalToConstant: 32),

            folderAssignmentPopup.widthAnchor.constraint(equalToConstant: 190)
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
        let folders = favoriteStore.folders
        guard !folders.isEmpty else {
            folderAssignmentPopup.addItem(withTitle: L10n.tr("settings.favorites.folder.none"))
            folderAssignmentPopup.isEnabled = false
            return
        }

        for folder in folders {
            folderAssignmentPopup.addItem(withTitle: folder.name)
            folderAssignmentPopup.lastItem?.representedObject = folder.id
        }
        folderAssignmentPopup.isEnabled = true
    }
}
