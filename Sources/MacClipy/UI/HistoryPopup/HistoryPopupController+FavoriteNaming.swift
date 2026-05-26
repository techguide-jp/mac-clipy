import AppKit

private enum FavoriteNamePromptMetrics {
    static let textFieldSize = NSSize(width: 320, height: 24)
}

extension HistoryPopupController {
    func promptForFavoriteTitle(defaultTitle: String) -> String? {
        let alert = NSAlert()
        alert.messageText = L10n.tr("historyPopup.favoriteName.title")
        alert.informativeText = L10n.tr("historyPopup.favoriteName.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.tr("historyPopup.favoriteName.add"))
        alert.addButton(withTitle: L10n.tr("button.cancel"))

        let textField = NSTextField(frame: NSRect(origin: .zero, size: FavoriteNamePromptMetrics.textFieldSize))
        textField.stringValue = defaultTitle
        textField.selectText(nil)
        alert.accessoryView = textField

        isShowingFavoriteNamePrompt = true
        defer {
            isShowingFavoriteNamePrompt = false
            window?.makeKeyAndOrderFront(nil)
        }

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let trimmedTitle = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? defaultTitle : trimmedTitle
    }
}
