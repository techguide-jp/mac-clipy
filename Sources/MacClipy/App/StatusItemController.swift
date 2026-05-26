import AppKit
import KeyboardShortcuts

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let historyModel: ClipboardHistoryModel
    private let monitorState: () -> Bool
    private let onCopyHistoryItem: (ClipboardItem) -> Void
    private let onShowHistory: () -> Void
    private let onShowFavorites: () -> Void
    private let onTogglePause: () -> Void
    private let onClearHistory: () -> Void
    private let onShowSettings: () -> Void
    private let onQuit: () -> Void

    private var statusItem: NSStatusItem?

    init(
        historyModel: ClipboardHistoryModel,
        monitorState: @escaping () -> Bool,
        onCopyHistoryItem: @escaping (ClipboardItem) -> Void,
        onShowHistory: @escaping () -> Void,
        onShowFavorites: @escaping () -> Void,
        onTogglePause: @escaping () -> Void,
        onClearHistory: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.historyModel = historyModel
        self.monitorState = monitorState
        self.onCopyHistoryItem = onCopyHistoryItem
        self.onShowHistory = onShowHistory
        self.onShowFavorites = onShowFavorites
        self.onTogglePause = onTogglePause
        self.onClearHistory = onClearHistory
        self.onShowSettings = onShowSettings
        self.onQuit = onQuit
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: AppConstants.MenuBar.statusItemWidth)
        statusItem = item

        if let button = item.button {
            button.image = nil
            button.imagePosition = .noImage
            button.title = "MacClipy"
            button.toolTip = "MacClipy"
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        rebuild()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    func rebuild() {
        guard let menu = statusItem?.menu else {
            return
        }

        menu.removeAllItems()
        addHistoryItems(to: menu)
        menu.addItem(.separator())
        addStatusItems(to: menu)
        menu.addItem(.separator())
        addCommandItems(to: menu)
    }

    private func addHistoryItems(to menu: NSMenu) {
        if historyModel.items.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.tr("menu.emptyHistory"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        for (index, item) in historyModel.items.prefix(AppConstants.MenuBar.recentHistoryItemLimit).enumerated() {
            let menuNumber = index + 1
            let menuItem = NSMenuItem(
                title: "\(menuNumber). \(item.menuTitle)",
                action: #selector(copyMenuItem(_:)),
                keyEquivalent: index < AppConstants.MenuBar.keyEquivalentItemLimit ? "\(menuNumber)" : ""
            )
            menuItem.target = self
            menuItem.representedObject = item.id.uuidString
            menu.addItem(menuItem)
        }
    }

    private func addStatusItems(to menu: NSMenu) {
        let hotKeyItem = NSMenuItem(
            title: L10n.tr("menu.hotKey", shortcutDisplayName(for: .showHistory)),
            action: nil,
            keyEquivalent: ""
        )
        hotKeyItem.isEnabled = false
        menu.addItem(hotKeyItem)

        let favoriteHotKeyItem = NSMenuItem(
            title: L10n.tr("menu.favoriteHotKey", shortcutDisplayName(for: .showFavorites)),
            action: nil,
            keyEquivalent: ""
        )
        favoriteHotKeyItem.isEnabled = false
        menu.addItem(favoriteHotKeyItem)

        if monitorState() {
            let pausedItem = NSMenuItem(title: L10n.tr("menu.pauseStatus"), action: nil, keyEquivalent: "")
            pausedItem.isEnabled = false
            menu.addItem(pausedItem)
        }
    }

    private func addCommandItems(to menu: NSMenu) {
        let searchItem = NSMenuItem(title: L10n.tr("menu.search"), action: #selector(showHistory), keyEquivalent: "")
        searchItem.target = self
        menu.addItem(searchItem)

        let favoritesItem = NSMenuItem(title: L10n.tr("menu.favorites"), action: #selector(showFavorites), keyEquivalent: "")
        favoritesItem.target = self
        menu.addItem(favoritesItem)

        let pauseTitle = monitorState() ? L10n.tr("menu.pauseResume") : L10n.tr("menu.pauseStart")
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        let settingsItem = NSMenuItem(title: L10n.tr("menu.settings"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let clearItem = NSMenuItem(title: L10n.tr("menu.clearHistory"), action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = !historyModel.items.isEmpty
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.tr("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func shortcutDisplayName(for name: KeyboardShortcuts.Name) -> String {
        KeyboardShortcuts.getShortcut(for: name).map { "\($0)" } ?? L10n.tr("settings.shortcut.notSet")
    }

    @objc private func copyMenuItem(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let item = historyModel.items.first(where: { $0.id == id }) else {
            return
        }

        onCopyHistoryItem(item)
    }

    @objc private func showHistory() {
        onShowHistory()
    }

    @objc private func showFavorites() {
        onShowFavorites()
    }

    @objc private func togglePause() {
        onTogglePause()
    }

    @objc private func clearHistory() {
        onClearHistory()
    }

    @objc private func showSettings() {
        onShowSettings()
    }

    @objc private func quit() {
        onQuit()
    }
}
