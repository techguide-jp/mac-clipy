import AppKit

@MainActor
final class HistoryPopupController: NSWindowController,
                                    NSSearchFieldDelegate,
                                    NSTableViewDataSource,
                                    NSTableViewDelegate,
                                    NSWindowDelegate {
    private let store: ClipboardStore
    private let onItemChosen: (ClipboardItem) -> Void

    private let searchField = NSSearchField()
    private let tableView = PopupKeyHandlingTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var results: [ClipboardItem] = []

    init(store: ClipboardStore, onItemChosen: @escaping (ClipboardItem) -> Void) {
        self.store = store
        self.onItemChosen = onItemChosen

        let panel = PopupPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
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
        buildInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(at screenPoint: NSPoint) {
        searchField.stringValue = ""
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
        reloadResults()
    }

    func closePopup() {
        window?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
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
        rootView.layer?.cornerRadius = 10
        rootView.layer?.masksToBounds = true
        window.contentView = rootView

        searchField.placeholderString = "履歴を検索"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(chooseSelectedItem)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("historyPopupItem"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 42
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.doubleAction = #selector(chooseSelectedItem)
        tableView.target = self
        tableView.onReturn = { [weak self] in
            self?.chooseSelectedItem()
        }
        tableView.onEscape = { [weak self] in
            self?.closePopup()
        }
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

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(searchField)
        rootView.addSubview(scrollView)
        rootView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -6),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -6),

            statusLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -8)
        ])
    }

    private func reloadResults() {
        results = store.search(searchField.stringValue)
        tableView.reloadData()

        if results.isEmpty {
            statusLabel.stringValue = "一致する履歴はありません"
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        let countText = results.count == store.items.count ? "\(results.count) 件" : "\(results.count) / \(store.items.count) 件"
        statusLabel.stringValue = "\(countText)  Enterで貼り付け / Escで閉じる"
    }

    private func origin(for screenPoint: NSPoint, windowSize: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first { NSMouseInRect(screenPoint, $0.frame, false) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            return screenPoint
        }

        let padding: CGFloat = 8
        let proposedX = min(screenPoint.x, visibleFrame.maxX - windowSize.width - padding)
        let proposedY = min(screenPoint.y - windowSize.height, visibleFrame.maxY - windowSize.height - padding)
        let clampedX = max(visibleFrame.minX + padding, proposedX)
        let clampedY = max(visibleFrame.minY + padding, proposedY)
        return NSPoint(x: clampedX, y: clampedY)
    }

    @objc private func chooseSelectedItem() {
        guard !results.isEmpty else {
            return
        }

        let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        guard results.indices.contains(selectedRow) else {
            return
        }

        let item = results[selectedRow]
        closePopup()
        onItemChosen(item)
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
        cell.configure(with: results[row])
        return cell
    }
}

private final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

private final class HistoryPopupCellView: NSTableCellView {
    private let titleField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setupFields()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: ClipboardItem) {
        titleField.stringValue = item.menuTitle
        subtitleField.stringValue = item.sourceBundleID ?? "取得元不明"
        toolTip = item.content
    }

    private func setupFields() {
        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false

        subtitleField.font = .systemFont(ofSize: 11)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingTail
        subtitleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleField)
        addSubview(subtitleField)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleField.topAnchor.constraint(equalTo: topAnchor, constant: 5),

            subtitleField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            subtitleField.trailingAnchor.constraint(equalTo: titleField.trailingAnchor),
            subtitleField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 1)
        ])
    }
}

private final class PopupKeyHandlingTableView: NSTableView {
    var onReturn: (() -> Void)?
    var onEscape: (() -> Void)?
    var onSearchFocus: (() -> Void)?
    var onPrintableKey: ((String) -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36:
            onReturn?()
        case 53:
            onEscape?()
        case 125:
            moveSelection(by: 1)
        case 126:
            moveSelection(by: -1)
        default:
            if shouldAppendToSearch(event), let text = event.charactersIgnoringModifiers {
                onSearchFocus?()
                onPrintableKey?(text)
                return
            }
            super.keyDown(with: event)
        }
    }

    private func moveSelection(by offset: Int) {
        guard numberOfRows > 0 else {
            return
        }

        let currentRow = selectedRow >= 0 ? selectedRow : 0
        let nextRow = min(max(currentRow + offset, 0), numberOfRows - 1)
        selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        scrollRowToVisible(nextRow)
    }

    private func shouldAppendToSearch(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control) else {
            return false
        }

        return event.charactersIgnoringModifiers?.count == 1
    }
}
