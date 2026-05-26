import AppKit

final class PopupPanel: NSPanel {
    var onKeyEquivalent: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKeyEquivalent?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class HistoryPopupCellView: NSTableCellView {
    private let titleField = NSTextField(labelWithString: "")
    private let starButton = NSButton()

    var onToggleFavorite: (() -> Void)?

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setupFields()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: ClipboardItem, isFavorite: Bool) {
        titleField.stringValue = item.menuTitle
        toolTip = item.content
        let symbolName = isFavorite ? "star.fill" : "star"
        let description = L10n.tr("favorites.toggle")
        starButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        starButton.contentTintColor = isFavorite ? .systemYellow : .secondaryLabelColor
    }

    private func setupFields() {
        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false

        starButton.bezelStyle = .inline
        starButton.isBordered = false
        starButton.target = self
        starButton.action = #selector(toggleFavorite)
        starButton.toolTip = L10n.tr("favorites.toggle")
        starButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleField)
        addSubview(starButton)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(equalTo: starButton.leadingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),

            starButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            starButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            starButton.widthAnchor.constraint(equalToConstant: 24),
            starButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @objc private func toggleFavorite() {
        onToggleFavorite?()
    }
}

final class PopupKeyHandlingTableView: NSTableView {
    enum CommandAction {
        case toggleFavorite
        case toggleMode
        case folder(Int)
    }

    var onReturn: (() -> Void)?
    var onEscape: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
    var onToggleMode: (() -> Void)?
    var onFolderShortcut: ((Int) -> Void)?
    var onSearchFocus: (() -> Void)?
    var onPrintableKey: ((String) -> Void)?

    override func keyDown(with event: NSEvent) {
        if let action = Self.commandAction(for: event) {
            handleCommandAction(action)
            return
        }

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

    static func commandAction(for event: NSEvent) -> CommandAction? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return nil
        }

        if key == "d", !modifiers.contains(.shift) {
            return .toggleFavorite
        }
        if key == "f", modifiers.contains(.shift) {
            return .toggleMode
        }
        if !modifiers.contains(.shift), let index = Int(key), (1...9).contains(index) {
            return .folder(index)
        }
        return nil
    }

    private func handleCommandAction(_ action: CommandAction) {
        switch action {
        case .toggleFavorite:
            onToggleFavorite?()
        case .toggleMode:
            onToggleMode?()
        case .folder(let index):
            onFolderShortcut?(index)
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
