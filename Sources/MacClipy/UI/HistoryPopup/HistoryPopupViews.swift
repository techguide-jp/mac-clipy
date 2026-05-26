import AppKit
import Carbon

private enum HistoryPopupCellMetrics {
    static let titleFontSize: CGFloat = 13
    static let horizontalPadding: CGFloat = 10
    static let titleToStarSpacing: CGFloat = 8
    static let starButtonSize: CGFloat = 24
}

private enum PopupNavigationKeyCode {
    static let returnKey = UInt16(kVK_Return)
    static let escape = UInt16(kVK_Escape)
    static let downArrow = UInt16(kVK_DownArrow)
    static let upArrow = UInt16(kVK_UpArrow)
}

final class PopupPanel: NSPanel {
    var onKeyEquivalent: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 検索欄フォーカス中でも、Command系は検索文字列へ混入させず処理する。
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

    func containsFavoriteButton(pointInCell: NSPoint) -> Bool {
        starButton.frame.contains(pointInCell)
    }

    private func setupFields() {
        titleField.font = .systemFont(ofSize: HistoryPopupCellMetrics.titleFontSize, weight: .medium)
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
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: HistoryPopupCellMetrics.horizontalPadding),
            titleField.trailingAnchor.constraint(
                equalTo: starButton.leadingAnchor,
                constant: -HistoryPopupCellMetrics.titleToStarSpacing
            ),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),

            starButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -HistoryPopupCellMetrics.horizontalPadding),
            starButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            starButton.widthAnchor.constraint(equalToConstant: HistoryPopupCellMetrics.starButtonSize),
            starButton.heightAnchor.constraint(equalToConstant: HistoryPopupCellMetrics.starButtonSize)
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

    var onRowClick: ((Int) -> Void)?

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: location)
        let clickedFavoriteButton = isFavoriteButtonClick(row: clickedRow, location: location)

        super.mouseUp(with: event)

        // スター以外の行クリックは、選択だけでなく貼り付けまで行う。
        guard clickedRow >= 0, !clickedFavoriteButton else {
            return
        }
        onRowClick?(clickedRow)
    }

    override func keyDown(with event: NSEvent) {
        if let action = Self.commandAction(for: event) {
            handleCommandAction(action)
            return
        }

        switch event.keyCode {
        case PopupNavigationKeyCode.returnKey:
            onReturn?()
        case PopupNavigationKeyCode.escape:
            onEscape?()
        case PopupNavigationKeyCode.downArrow:
            moveSelection(by: 1)
        case PopupNavigationKeyCode.upArrow:
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
        // Command系は検索入力へ流さず、操作ショートカットとして先に解釈する。
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
        if !modifiers.contains(.shift),
           let index = Int(key),
           (AppConstants.Keyboard.firstFolderShortcutIndex...AppConstants.Keyboard.lastFolderShortcutIndex)
            .contains(index) {
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

    private func isFavoriteButtonClick(row: Int, location: NSPoint) -> Bool {
        guard row >= 0,
              let cell = view(atColumn: 0, row: row, makeIfNecessary: false) as? HistoryPopupCellView else {
            return false
        }

        let pointInCell = cell.convert(location, from: self)
        return cell.containsFavoriteButton(pointInCell: pointInCell)
    }
}
