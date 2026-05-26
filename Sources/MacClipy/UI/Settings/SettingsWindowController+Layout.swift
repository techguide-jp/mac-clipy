import AppKit

private enum SettingsLayoutMetrics {
    static let generalTabIndex = 0
    static let excludedAppsTabIndex = 1
    static let favoritesTabIndex = 2
    static let footerStatusFontSize: CGFloat = 12
    static let tabOuterPadding: CGFloat = 12
    static let footerHorizontalPadding: CGFloat = 16
    static let footerBottomPadding: CGFloat = 14
    static let footerButtonSpacing: CGFloat = 8
    static let sectionPadding: CGFloat = 18
    static let labelHelpSpacing: CGFloat = 4
    static let controlSpacing: CGFloat = 8
    static let shortcutButtonSpacing: CGFloat = 10
    static let shortcutRecorderHeight: CGFloat = 54
    static let resetButtonWidth: CGFloat = 110
    static let shortcutSectionSpacing: CGFloat = 22
    static let tableBottomPadding: CGFloat = 16
    static let favoriteFolderColumnWidth: CGFloat = 220
    static let favoriteColumnSpacing: CGFloat = 20
    static let favoriteSortPopupWidth: CGFloat = 180
    static let favoriteSortLabelSpacing: CGFloat = 12
    static let toolbarHeight: CGFloat = 32
    static let folderAssignmentPopupWidth: CGFloat = 190
    static let excludedAppRowHeight: CGFloat = 30
    static let favoriteFolderRowHeight: CGFloat = 28
    static let favoriteItemRowHeight: CGFloat = 30
    static let favoriteTitleColumnWidth: CGFloat = 250
    static let favoriteFoldersColumnWidth: CGFloat = 170
    static let itemToolbarSpacerSpacing: CGFloat = 14
}

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
        tabView.tabViewItem(at: SettingsLayoutMetrics.generalTabIndex).label = L10n.tr("settings.tab.general")
        tabView.tabViewItem(at: SettingsLayoutMetrics.generalTabIndex).view = buildGeneralTab()
        tabView.addTabViewItem(NSTabViewItem(viewController: NSViewController()))
        tabView.tabViewItem(at: SettingsLayoutMetrics.excludedAppsTabIndex).label = L10n.tr("settings.tab.excludedApps")
        tabView.tabViewItem(at: SettingsLayoutMetrics.excludedAppsTabIndex).view = buildExcludedAppsTab()
        tabView.addTabViewItem(NSTabViewItem(viewController: NSViewController()))
        tabView.tabViewItem(at: SettingsLayoutMetrics.favoritesTabIndex).label = L10n.tr("settings.tab.favorites")
        tabView.tabViewItem(at: SettingsLayoutMetrics.favoritesTabIndex).view = buildFavoritesTab()

        let saveButton = NSButton(title: L10n.tr("button.save"), target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: L10n.tr("button.cancel"), target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: SettingsLayoutMetrics.footerStatusFontSize)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(tabView)
        contentView.addSubview(statusLabel)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SettingsLayoutMetrics.tabOuterPadding),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SettingsLayoutMetrics.tabOuterPadding),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SettingsLayoutMetrics.tabOuterPadding),
            tabView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -SettingsLayoutMetrics.tabOuterPadding),

            statusLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: SettingsLayoutMetrics.footerHorizontalPadding
            ),
            statusLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: cancelButton.leadingAnchor,
                constant: -SettingsLayoutMetrics.tabOuterPadding
            ),
            statusLabel.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),

            cancelButton.trailingAnchor.constraint(
                equalTo: saveButton.leadingAnchor,
                constant: -SettingsLayoutMetrics.footerButtonSpacing
            ),
            cancelButton.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -SettingsLayoutMetrics.footerBottomPadding
            ),

            saveButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -SettingsLayoutMetrics.footerHorizontalPadding
            ),
            saveButton.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -SettingsLayoutMetrics.footerBottomPadding
            )
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
            historyLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            historyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            historyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SettingsLayoutMetrics.sectionPadding),

            historyHelpLabel.topAnchor.constraint(
                equalTo: historyLabel.bottomAnchor,
                constant: SettingsLayoutMetrics.labelHelpSpacing
            ),
            historyHelpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            historyHelpLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -SettingsLayoutMetrics.sectionPadding
            ),

            shortcutRecorder.topAnchor.constraint(
                equalTo: historyHelpLabel.bottomAnchor,
                constant: SettingsLayoutMetrics.controlSpacing
            ),
            shortcutRecorder.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            shortcutRecorder.trailingAnchor.constraint(
                equalTo: resetShortcutButton.leadingAnchor,
                constant: -SettingsLayoutMetrics.shortcutButtonSpacing
            ),
            shortcutRecorder.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.shortcutRecorderHeight),

            resetShortcutButton.centerYAnchor.constraint(equalTo: shortcutRecorder.centerYAnchor),
            resetShortcutButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -SettingsLayoutMetrics.sectionPadding
            ),
            resetShortcutButton.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.resetButtonWidth),

            favoriteLabel.topAnchor.constraint(
                equalTo: shortcutRecorder.bottomAnchor,
                constant: SettingsLayoutMetrics.shortcutSectionSpacing
            ),
            favoriteLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            favoriteLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SettingsLayoutMetrics.sectionPadding),

            favoriteHelpLabel.topAnchor.constraint(
                equalTo: favoriteLabel.bottomAnchor,
                constant: SettingsLayoutMetrics.labelHelpSpacing
            ),
            favoriteHelpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            favoriteHelpLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -SettingsLayoutMetrics.sectionPadding
            ),

            favoriteShortcutRecorder.topAnchor.constraint(
                equalTo: favoriteHelpLabel.bottomAnchor,
                constant: SettingsLayoutMetrics.controlSpacing
            ),
            favoriteShortcutRecorder.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: SettingsLayoutMetrics.sectionPadding
            ),
            favoriteShortcutRecorder.trailingAnchor.constraint(
                equalTo: resetFavoriteShortcutButton.leadingAnchor,
                constant: -SettingsLayoutMetrics.shortcutButtonSpacing
            ),
            favoriteShortcutRecorder.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.shortcutRecorderHeight),

            resetFavoriteShortcutButton.centerYAnchor.constraint(equalTo: favoriteShortcutRecorder.centerYAnchor),
            resetFavoriteShortcutButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -SettingsLayoutMetrics.sectionPadding
            ),
            resetFavoriteShortcutButton.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.resetButtonWidth)
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
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SettingsLayoutMetrics.sectionPadding),

            excludedAppsHelpLabel.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: SettingsLayoutMetrics.labelHelpSpacing
            ),
            excludedAppsHelpLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: SettingsLayoutMetrics.sectionPadding
            ),
            excludedAppsHelpLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -SettingsLayoutMetrics.sectionPadding
            ),

            scrollView.topAnchor.constraint(
                equalTo: excludedAppsHelpLabel.bottomAnchor,
                constant: SettingsLayoutMetrics.shortcutButtonSpacing
            ),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SettingsLayoutMetrics.sectionPadding),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -SettingsLayoutMetrics.shortcutButtonSpacing),

            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            addButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -SettingsLayoutMetrics.tableBottomPadding),

            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: SettingsLayoutMetrics.controlSpacing),
            removeButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),

            resetButton.leadingAnchor.constraint(equalTo: removeButton.trailingAnchor, constant: SettingsLayoutMetrics.controlSpacing),
            resetButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            resetButton.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -SettingsLayoutMetrics.sectionPadding
            )
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
            spacing: SettingsLayoutMetrics.controlSpacing
        )
        itemToolbar.setCustomSpacing(SettingsLayoutMetrics.itemToolbarSpacerSpacing, after: itemToolbarSpacer)

        let views: [NSView] = [
            foldersLabel, folderScrollView, folderToolbar, itemsLabel, favoriteSortPopup, itemScrollView, itemToolbar
        ]
        views.forEach(view.addSubview)

        NSLayoutConstraint.activate([
            foldersLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            foldersLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SettingsLayoutMetrics.sectionPadding),

            folderScrollView.topAnchor.constraint(
                equalTo: foldersLabel.bottomAnchor,
                constant: SettingsLayoutMetrics.controlSpacing
            ),
            folderScrollView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: SettingsLayoutMetrics.sectionPadding
            ),
            folderScrollView.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.favoriteFolderColumnWidth),
            folderScrollView.bottomAnchor.constraint(equalTo: folderToolbar.topAnchor, constant: -SettingsLayoutMetrics.controlSpacing),

            folderToolbar.leadingAnchor.constraint(equalTo: folderScrollView.leadingAnchor),
            folderToolbar.trailingAnchor.constraint(lessThanOrEqualTo: folderScrollView.trailingAnchor),
            folderToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -SettingsLayoutMetrics.tableBottomPadding),
            folderToolbar.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.toolbarHeight),

            itemsLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: SettingsLayoutMetrics.sectionPadding),
            itemsLabel.leadingAnchor.constraint(
                equalTo: folderScrollView.trailingAnchor,
                constant: SettingsLayoutMetrics.favoriteColumnSpacing
            ),

            favoriteSortPopup.centerYAnchor.constraint(equalTo: itemsLabel.centerYAnchor),
            favoriteSortPopup.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -SettingsLayoutMetrics.sectionPadding
            ),
            favoriteSortPopup.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.favoriteSortPopupWidth),
            itemsLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: favoriteSortPopup.leadingAnchor,
                constant: -SettingsLayoutMetrics.favoriteSortLabelSpacing
            ),

            itemScrollView.topAnchor.constraint(equalTo: itemsLabel.bottomAnchor, constant: SettingsLayoutMetrics.controlSpacing),
            itemScrollView.leadingAnchor.constraint(equalTo: itemsLabel.leadingAnchor),
            itemScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SettingsLayoutMetrics.sectionPadding),
            itemScrollView.bottomAnchor.constraint(equalTo: itemToolbar.topAnchor, constant: -SettingsLayoutMetrics.controlSpacing),

            itemToolbar.leadingAnchor.constraint(equalTo: itemScrollView.leadingAnchor),
            itemToolbar.trailingAnchor.constraint(equalTo: itemScrollView.trailingAnchor),
            itemToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -SettingsLayoutMetrics.tableBottomPadding),
            itemToolbar.heightAnchor.constraint(equalToConstant: SettingsLayoutMetrics.toolbarHeight),

            folderAssignmentPopup.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.folderAssignmentPopupWidth)
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
        excludedAppsTableView.rowHeight = SettingsLayoutMetrics.excludedAppRowHeight
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
            favoriteFoldersTableView.rowHeight = SettingsLayoutMetrics.favoriteFolderRowHeight
            favoriteFoldersTableView.translatesAutoresizingMaskIntoConstraints = false
            favoriteFoldersTableView.action = #selector(favoriteFolderSelectionChanged)
            favoriteFoldersTableView.target = self
        }

        if favoriteItemsTableView.tableColumns.isEmpty {
            let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("favoriteTitle"))
            titleColumn.title = L10n.tr("settings.favorites.column.title")
            titleColumn.width = SettingsLayoutMetrics.favoriteTitleColumnWidth
            favoriteItemsTableView.addTableColumn(titleColumn)

            let foldersColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("favoriteFolders"))
            foldersColumn.title = L10n.tr("settings.favorites.column.folders")
            foldersColumn.width = SettingsLayoutMetrics.favoriteFoldersColumnWidth
            favoriteItemsTableView.addTableColumn(foldersColumn)

            favoriteItemsTableView.delegate = self
            favoriteItemsTableView.dataSource = self
            favoriteItemsTableView.rowHeight = SettingsLayoutMetrics.favoriteItemRowHeight
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
