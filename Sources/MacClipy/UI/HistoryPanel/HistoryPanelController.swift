import AppKit

@MainActor
final class HistoryPanelController: NSWindowController,
                                    NSTableViewDataSource,
                                    NSTableViewDelegate,
                                    NSSearchFieldDelegate {
    private let store: ClipboardStore
    private let onItemChosen: (ClipboardItem) -> Void

    private let searchField = NSSearchField()
    private let tableView = KeyHandlingTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var results: [ClipboardItem] = []

    init(store: ClipboardStore, onItemChosen: @escaping (ClipboardItem) -> Void) {
        self.store = store
        self.onItemChosen = onItemChosen

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacClipy"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.tabbingMode = .disallowed
        window.contentMinSize = NSSize(width: 420, height: 260)

        super.init(window: window)
        buildInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        searchField.stringValue = ""
        reloadResults()

        if let window {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            window.makeFirstResponder(searchField)
        }
    }

    func refresh() {
        reloadResults()
    }

    private func buildInterface() {
        guard let window else {
            return
        }

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        searchField.placeholderString = L10n.tr("historyPanel.searchPlaceholder")
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(chooseSelectedItem)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.title = L10n.tr("historyPanel.columnTitle")
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 54
        tableView.doubleAction = #selector(chooseSelectedItem)
        tableView.target = self
        tableView.onReturn = { [weak self] in
            self?.chooseSelectedItem()
        }
        tableView.onDelete = { [weak self] in
            self?.deleteSelectedItem()
        }
        tableView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(searchField)
        contentView.addSubview(scrollView)
        contentView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    private func reloadResults() {
        results = store.search(searchField.stringValue)
        tableView.reloadData()

        if !results.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        statusLabel.stringValue = results.isEmpty
            ? L10n.tr("historyPanel.noMatches")
            : L10n.tr("historyPanel.resultCount", results.count)
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
        window?.orderOut(nil)
        onItemChosen(item)
    }

    private func deleteSelectedItem() {
        let selectedRow = tableView.selectedRow
        guard results.indices.contains(selectedRow) else {
            return
        }

        do {
            try store.delete(id: results[selectedRow].id)
            reloadResults()
        } catch {
            statusLabel.stringValue = L10n.tr("historyPanel.deleteFailed", error.localizedDescription)
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        reloadResults()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        results.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard results.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("clipCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? ClipboardCellView(identifier: identifier)

        cell.textField?.stringValue = results[row].menuTitle
        cell.toolTip = results[row].content
        return cell
    }
}

private final class ClipboardCellView: NSTableCellView {
    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier

        let textField = NSTextField(labelWithString: "")
        textField.font = .systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 2
        textField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textField)
        self.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class KeyHandlingTableView: NSTableView {
    var onReturn: (() -> Void)?
    var onDelete: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36:
            onReturn?()
        case 51:
            onDelete?()
        default:
            super.keyDown(with: event)
        }
    }
}
