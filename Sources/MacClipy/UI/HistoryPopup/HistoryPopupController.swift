import AppKit

enum HistoryPopupInitialMode {
    case all
    case favorites
}

@MainActor
final class HistoryPopupController: NSWindowController,
                                    NSSearchFieldDelegate,
                                    NSTableViewDataSource,
                                    NSTableViewDelegate,
                                    NSWindowDelegate {
    private enum PopupMode: Int, CaseIterable {
        case all
        case favorites
    }

    private enum FavoriteFolderFilter: Equatable {
        case all
        case unclassified
        case folder(UUID)
    }

    private struct PopupResult {
        let item: ClipboardItem
        let favorite: FavoriteItem?
    }

    private let store: ClipboardStore
    private let favoriteStore: FavoriteStore
    private let onItemChosen: (ClipboardItem) -> Void
    private let onSettingsRequested: () -> Void

    private let searchField = NSSearchField()
    private let settingsButton = NSButton()
    private let filterSegment = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
    private let folderPopup = NSPopUpButton()
    private let tableView = PopupKeyHandlingTableView()
    private let emptyLabel = NSTextField(labelWithString: "")

    private var mode: PopupMode = .all
    private var folderFilter: FavoriteFolderFilter = .all
    private var results: [PopupResult] = []
    var isShowingFavoriteNamePrompt = false

    init(
        store: ClipboardStore,
        favoriteStore: FavoriteStore,
        onItemChosen: @escaping (ClipboardItem) -> Void,
        onSettingsRequested: @escaping () -> Void
    ) {
        self.store = store
        self.favoriteStore = favoriteStore
        self.onItemChosen = onItemChosen
        self.onSettingsRequested = onSettingsRequested

        let panel = PopupPanel(
            contentRect: NSRect(origin: .zero, size: HistoryPopupMetrics.panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear

        super.init(window: panel)
        panel.delegate = self
        panel.onKeyEquivalent = { [weak self] event in
            self?.handleCommandEvent(event) ?? false
        }
        buildInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(at screenPoint: NSPoint, initialMode: HistoryPopupInitialMode) {
        searchField.stringValue = ""
        mode = initialMode == .favorites ? .favorites : .all
        folderFilter = .all
        filterSegment.selectedSegment = mode.rawValue
        reloadFolderPopup()
        reloadResults()

        guard let window else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        window.setFrameOrigin(origin(for: screenPoint, windowSize: window.frame.size))
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(searchField)
    }

    func refresh() {
        reloadFolderPopup()
        reloadResults()
    }

    func closePopup() {
        window?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isShowingFavoriteNamePrompt else {
            return
        }
        closePopup()
    }

    private func buildInterface() {
        guard let window else {
            return
        }

        let rootView = NSVisualEffectView()
        rootView.material = .popover
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.translatesAutoresizingMaskIntoConstraints = false
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = HistoryPopupMetrics.cornerRadius
        rootView.layer?.masksToBounds = true
        window.contentView = rootView

        configureSearchField()
        configureSettingsButton()
        configureFilters()
        configureTableView()

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.stringValue = L10n.tr("historyPopup.noMatches")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: HistoryPopupMetrics.emptyLabelFontSize)
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(searchField)
        rootView.addSubview(settingsButton)
        rootView.addSubview(filterSegment)
        rootView.addSubview(folderPopup)
        rootView.addSubview(scrollView)
        rootView.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: rootView.topAnchor, constant: HistoryPopupMetrics.outerPadding),
            searchField.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: HistoryPopupMetrics.outerPadding),
            searchField.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -HistoryPopupMetrics.controlSpacing),

            settingsButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -HistoryPopupMetrics.outerPadding),
            settingsButton.widthAnchor.constraint(equalToConstant: HistoryPopupMetrics.settingsButtonWidth),

            filterSegment.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: HistoryPopupMetrics.controlSpacing),
            filterSegment.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: HistoryPopupMetrics.outerPadding),
            filterSegment.widthAnchor.constraint(equalToConstant: HistoryPopupMetrics.filterSegmentWidth),

            folderPopup.centerYAnchor.constraint(equalTo: filterSegment.centerYAnchor),
            folderPopup.leadingAnchor.constraint(equalTo: filterSegment.trailingAnchor, constant: HistoryPopupMetrics.controlSpacing),
            folderPopup.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -HistoryPopupMetrics.outerPadding),

            scrollView.topAnchor.constraint(equalTo: filterSegment.bottomAnchor, constant: HistoryPopupMetrics.controlSpacing),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: HistoryPopupMetrics.scrollHorizontalInset),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -HistoryPopupMetrics.scrollHorizontalInset),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -HistoryPopupMetrics.scrollHorizontalInset),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: scrollView.leadingAnchor,
                constant: HistoryPopupMetrics.emptyLabelHorizontalPadding
            ),
            emptyLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: scrollView.trailingAnchor,
                constant: -HistoryPopupMetrics.emptyLabelHorizontalPadding
            )
        ])
    }
}

extension HistoryPopupController {
    private func configureSearchField() {
        searchField.placeholderString = L10n.tr("historyPopup.searchPlaceholder")
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(chooseSelectedItem)
        searchField.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureSettingsButton() {
        let settingsTitle = L10n.tr("button.settings")
        if let image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: settingsTitle) {
            settingsButton.image = image
            settingsButton.imagePosition = .imageOnly
        } else {
            settingsButton.title = settingsTitle
        }
        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.toolTip = settingsTitle
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureFilters() {
        filterSegment.segmentCount = PopupMode.allCases.count
        filterSegment.setLabel(L10n.tr("historyPopup.filter.all"), forSegment: PopupMode.all.rawValue)
        filterSegment.setLabel(L10n.tr("historyPopup.filter.favorites"), forSegment: PopupMode.favorites.rawValue)
        filterSegment.selectedSegment = mode.rawValue
        filterSegment.target = self
        filterSegment.action = #selector(changeFilterMode)
        filterSegment.translatesAutoresizingMaskIntoConstraints = false

        folderPopup.target = self
        folderPopup.action = #selector(changeFolderFilter)
        folderPopup.translatesAutoresizingMaskIntoConstraints = false
        reloadFolderPopup()
    }

    private func configureTableView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("historyPopupItem"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = HistoryPopupMetrics.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: HistoryPopupMetrics.rowSpacing)
        tableView.doubleAction = #selector(chooseSelectedItem)
        tableView.target = self
        tableView.onRowClick = { [weak self] row in
            self?.chooseItem(at: row)
        }
        tableView.onReturn = { [weak self] in self?.chooseSelectedItem() }
        tableView.onEscape = { [weak self] in self?.closePopup() }
        tableView.onToggleFavorite = { [weak self] in self?.toggleSelectedFavorite() }
        tableView.onToggleMode = { [weak self] in self?.toggleFavoriteMode() }
        tableView.onFolderShortcut = { [weak self] index in self?.selectFolderByShortcut(index) }
        tableView.onSearchFocus = { [weak self] in
            guard let self else {
                return
            }
            self.window?.makeFirstResponder(self.searchField)
        }
        tableView.onPrintableKey = { [weak self] text in
            self?.appendSearchText(text)
        }
        tableView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func reloadFolderPopup() {
        folderPopup.removeAllItems()
        folderPopup.addItem(withTitle: L10n.tr("historyPopup.folders.all"))
        folderPopup.lastItem?.representedObject = FavoriteFolderFilter.all
        folderPopup.addItem(withTitle: L10n.tr("historyPopup.folders.unclassified"))
        folderPopup.lastItem?.representedObject = FavoriteFolderFilter.unclassified

        for folder in favoriteStore.folders {
            folderPopup.addItem(withTitle: folder.name)
            folderPopup.lastItem?.representedObject = FavoriteFolderFilter.folder(folder.id)
        }

        if case .folder(let folderID) = folderFilter,
           !favoriteStore.folders.contains(where: { $0.id == folderID }) {
            self.folderFilter = .all
        }

        let selectedIndex = folderPopup.itemArray.firstIndex { item in
            guard let filter = item.representedObject as? FavoriteFolderFilter else {
                return false
            }
            return filter == folderFilter
        } ?? 0
        folderPopup.selectItem(at: selectedIndex)
        folderPopup.isEnabled = mode == .favorites
    }

    private func reloadResults(selecting row: Int = 0) {
        switch mode {
        case .all:
            results = store.search(searchField.stringValue).map { item in
                PopupResult(item: item, favorite: favoriteStore.favorite(for: item))
            }
        case .favorites:
            results = favoriteResults()
        }

        tableView.reloadData()
        emptyLabel.isHidden = !results.isEmpty

        if !results.isEmpty {
            let selectedRow = min(max(row, 0), results.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedRow)
        }
    }

    private func favoriteResults() -> [PopupResult] {
        let favorites: [FavoriteItem]
        switch folderFilter {
        case .all:
            favorites = favoriteStore.search(searchField.stringValue, folderID: nil)
        case .unclassified:
            let unclassifiedIDs = Set(favoriteStore.unclassifiedItems().map(\.id))
            favorites = favoriteStore.search(searchField.stringValue, folderID: nil).filter {
                unclassifiedIDs.contains($0.id)
            }
        case .folder(let folderID):
            favorites = favoriteStore.search(searchField.stringValue, folderID: folderID)
        }

        return favorites.map { favorite in
            PopupResult(item: favorite.clipboardItem, favorite: favorite)
        }
    }

    @objc private func chooseSelectedItem() {
        guard !results.isEmpty else {
            return
        }

        let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        chooseItem(at: selectedRow)
    }

    private func chooseItem(at row: Int) {
        guard results.indices.contains(row) else {
            return
        }

        let result = results[row]
        if let favorite = result.favorite {
            try? favoriteStore.markUsed(id: favorite.id)
        }

        closePopup()
        onItemChosen(result.item)
    }

    @objc private func openSettings() {
        closePopup()
        onSettingsRequested()
    }

    @objc private func changeFilterMode() {
        mode = filterSegment.selectedSegment == PopupMode.favorites.rawValue ? .favorites : .all
        folderPopup.isEnabled = mode == .favorites
        reloadResults()
    }

    @objc private func changeFolderFilter() {
        folderFilter = folderPopup.selectedItem?.representedObject as? FavoriteFolderFilter ?? .all
        mode = .favorites
        filterSegment.selectedSegment = mode.rawValue
        folderPopup.isEnabled = true
        reloadResults()
    }

    func controlTextDidChange(_ notification: Notification) {
        reloadResults()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            chooseSelectedItem()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            closePopup()
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true
        default:
            return false
        }
    }

    private func appendSearchText(_ text: String) {
        window?.makeFirstResponder(searchField)
        searchField.stringValue += text
        reloadResults()
    }

    private func moveSelection(by offset: Int) {
        guard !results.isEmpty else {
            return
        }

        let currentRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let nextRow = min(max(currentRow + offset, 0), results.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
    }

    private func toggleSelectedFavorite() {
        let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        guard results.indices.contains(selectedRow) else {
            return
        }

        toggleFavorite(at: selectedRow)
    }

    private func toggleFavorite(at row: Int) {
        guard results.indices.contains(row) else {
            return
        }

        do {
            if let favorite = results[row].favorite {
                try favoriteStore.removeFavorite(id: favorite.id)
            } else {
                let defaultTitle = FavoriteItem.defaultDisplayTitle(for: results[row].item.content)
                let displayTitle = promptForFavoriteTitle(defaultTitle: defaultTitle)
                window?.makeFirstResponder(tableView)
                guard let displayTitle else {
                    return
                }
                try favoriteStore.addFavorite(for: results[row].item, displayTitle: displayTitle)
            }
            reloadFolderPopup()
            reloadResults(selecting: row)
        } catch {
            NSLog("MacClipy failed to toggle favorite: \(error.localizedDescription)")
        }
    }

    private func toggleFavoriteMode() {
        mode = mode == .favorites ? .all : .favorites
        filterSegment.selectedSegment = mode.rawValue
        folderPopup.isEnabled = mode == .favorites
        reloadResults()
    }

    private func selectFolderByShortcut(_ shortcutIndex: Int) {
        let folders = favoriteStore.folders
        guard folders.indices.contains(shortcutIndex - 1) else {
            return
        }

        folderFilter = .folder(folders[shortcutIndex - 1].id)
        mode = .favorites
        filterSegment.selectedSegment = mode.rawValue
        reloadFolderPopup()
        reloadResults()
    }

    private func handleCommandEvent(_ event: NSEvent) -> Bool {
        PopupKeyHandlingTableView.commandAction(for: event).map { action in
            switch action {
            case .toggleFavorite:
                toggleSelectedFavorite()
            case .toggleMode:
                toggleFavoriteMode()
            case .folder(let index):
                selectFolderByShortcut(index)
            }
            return true
        } ?? false
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        results.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard results.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("historyPopupCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? HistoryPopupCellView
            ?? HistoryPopupCellView(identifier: identifier)
        cell.configure(with: results[row].item, isFavorite: results[row].favorite != nil)
        cell.onToggleFavorite = { [weak self] in
            self?.toggleFavorite(at: row)
        }
        return cell
    }
}
