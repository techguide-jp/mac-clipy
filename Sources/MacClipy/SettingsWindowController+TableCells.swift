import AppKit

extension SettingsWindowController {
    func excludedAppCell(row: Int) -> NSView? {
        guard excludedBundleIdentifiers.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("excludedAppCell")
        let cell = excludedAppsTableView.makeView(withIdentifier: identifier, owner: self) as? SettingsTextCellView
            ?? SettingsTextCellView(identifier: identifier)

        let bundleIdentifier = excludedBundleIdentifiers[row]
        cell.configure(text: displayName(for: bundleIdentifier), secondaryText: nil)
        cell.toolTip = bundleIdentifier
        return cell
    }

    func favoriteFolderCell(row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("favoriteFolderCell")
        let cell = favoriteFoldersTableView.makeView(withIdentifier: identifier, owner: self) as? SettingsTextCellView
            ?? SettingsTextCellView(identifier: identifier)

        if row == 0 {
            cell.configure(text: L10n.tr("settings.favorites.folder.all"), secondaryText: nil)
            return cell
        }
        if row == 1 {
            cell.configure(text: L10n.tr("settings.favorites.folder.unclassified"), secondaryText: nil)
            return cell
        }

        let folderIndex = row - 2
        guard favoriteStore.folders.indices.contains(folderIndex) else {
            return nil
        }
        cell.configure(text: favoriteStore.folders[folderIndex].name, secondaryText: nil)
        return cell
    }

    func favoriteItemCell(tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard favoriteRows.indices.contains(row) else {
            return nil
        }

        let favorite = favoriteRows[row]
        let identifier = NSUserInterfaceItemIdentifier("favoriteItemCell")
        let cell = favoriteItemsTableView.makeView(withIdentifier: identifier, owner: self) as? SettingsTextCellView
            ?? SettingsTextCellView(identifier: identifier)

        if tableColumn?.identifier.rawValue == "favoriteFolders" {
            configureFolderNamesCell(cell, favorite: favorite)
        } else {
            let detail = L10n.tr("settings.favorites.item.detail", favorite.useCount)
            cell.configure(text: favorite.menuTitle, secondaryText: detail)
            cell.toolTip = favorite.contentSnapshot
        }
        return cell
    }

    private func configureFolderNamesCell(_ cell: SettingsTextCellView, favorite: FavoriteItem) {
        let folderNames = favoriteStore.folderNames(for: favorite.id)
        let text = folderNames.isEmpty
            ? L10n.tr("settings.favorites.folder.unclassified")
            : folderNames.joined(separator: ", ")
        cell.configure(text: text, secondaryText: nil)
    }

    func promptForText(title: String, message: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.tr("button.ok"))
        alert.addButton(withTitle: L10n.tr("button.cancel"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        textField.stringValue = defaultValue
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        return textField.stringValue
    }

    func confirm(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.tr("button.delete"))
        alert.addButton(withTitle: L10n.tr("button.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}

private final class SettingsTextCellView: NSTableCellView {
    private let titleField = NSTextField(labelWithString: "")
    private let detailField = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setupFields()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String, secondaryText: String?) {
        titleField.stringValue = text
        detailField.stringValue = secondaryText ?? ""
        detailField.isHidden = secondaryText == nil
    }

    private func setupFields() {
        titleField.font = .systemFont(ofSize: 13)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false

        detailField.font = .systemFont(ofSize: 11)
        detailField.textColor = .secondaryLabelColor
        detailField.lineBreakMode = .byTruncatingTail
        detailField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleField)
        addSubview(detailField)
        textField = titleField

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleField.topAnchor.constraint(equalTo: topAnchor, constant: 3),

            detailField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            detailField.trailingAnchor.constraint(equalTo: titleField.trailingAnchor),
            detailField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 1)
        ])
    }
}
