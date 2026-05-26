import AppKit

private enum SettingsTableCellMetrics {
    static let promptTextFieldSize = NSSize(width: 320, height: 24)
    static let titleFontSize: CGFloat = 13
    static let detailFontSize: CGFloat = 11
    static let horizontalPadding: CGFloat = 8
    static let titleTopPadding: CGFloat = 3
    static let detailTopSpacing: CGFloat = 1
    static let detailBottomPadding: CGFloat = 4
}

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

        if row == Self.FavoriteFolderTableRows.all {
            cell.configure(text: L10n.tr("settings.favorites.folder.all"), secondaryText: nil)
            return cell
        }
        if row == Self.FavoriteFolderTableRows.unclassified {
            cell.configure(text: L10n.tr("settings.favorites.folder.unclassified"), secondaryText: nil)
            return cell
        }

        let folderIndex = row - Self.FavoriteFolderTableRows.concreteFolderOffset
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
            let detail = favoriteItemDetail(for: favorite)
            cell.configure(text: favorite.menuTitle, secondaryText: detail)
            cell.toolTip = favorite.hasCustomDisplayTitle
                ? "\(favorite.menuTitle)\n\(favorite.contentSnapshot)"
                : favorite.contentSnapshot
        }
        return cell
    }

    private func favoriteItemDetail(for favorite: FavoriteItem) -> String {
        guard favorite.hasCustomDisplayTitle else {
            return L10n.tr("settings.favorites.item.detail", favorite.useCount)
        }
        return L10n.tr(
            "settings.favorites.item.namedDetail",
            favorite.contentMenuTitle,
            favorite.useCount
        )
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

        let textField = NSTextField(frame: NSRect(origin: .zero, size: SettingsTableCellMetrics.promptTextFieldSize))
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
        titleField.font = .systemFont(ofSize: SettingsTableCellMetrics.titleFontSize)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false

        detailField.font = .systemFont(ofSize: SettingsTableCellMetrics.detailFontSize)
        detailField.textColor = .secondaryLabelColor
        detailField.lineBreakMode = .byTruncatingTail
        detailField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleField)
        addSubview(detailField)
        textField = titleField

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SettingsTableCellMetrics.horizontalPadding),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SettingsTableCellMetrics.horizontalPadding),
            titleField.topAnchor.constraint(equalTo: topAnchor, constant: SettingsTableCellMetrics.titleTopPadding),

            detailField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            detailField.trailingAnchor.constraint(equalTo: titleField.trailingAnchor),
            detailField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: SettingsTableCellMetrics.detailTopSpacing),
            detailField.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor,
                constant: -SettingsTableCellMetrics.detailBottomPadding
            )
        ])
    }
}
