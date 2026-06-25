import AppKit
import KeyboardShortcuts

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    enum CommandItem: Equatable {
        case settings
        case checkForUpdates
        case help
        case search
        case favorites
        case pause
        case clearHistory
        case separator
        case quit
    }

    static let commandItemOrder: [CommandItem] = [
        .settings,
        .checkForUpdates,
        .help,
        .search,
        .favorites,
        .pause,
        .clearHistory,
        .separator,
        .quit
    ]

    static let menuBarIconSymbolName = "clipboard"
    static let statusItemLength = NSStatusItem.squareLength

    private let historyModel: ClipboardHistoryModel
    private let monitorState: () -> Bool
    private let onCopyHistoryItem: (ClipboardItem) -> Void
    private let onShowHistory: () -> Void
    private let onShowFavorites: () -> Void
    private let onShowHelp: () -> Void
    private let onTogglePause: () -> Void
    private let onClearHistory: () -> Void
    private let onShowSettings: () -> Void
    private let canCheckForUpdates: () -> Bool
    private let onCheckForUpdates: () -> Void
    private let onQuit: () -> Void

    private var statusItem: NSStatusItem?

    init(
        historyModel: ClipboardHistoryModel,
        monitorState: @escaping () -> Bool,
        onCopyHistoryItem: @escaping (ClipboardItem) -> Void,
        onShowHistory: @escaping () -> Void,
        onShowFavorites: @escaping () -> Void,
        onShowHelp: @escaping () -> Void,
        onTogglePause: @escaping () -> Void,
        onClearHistory: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        canCheckForUpdates: @escaping () -> Bool,
        onCheckForUpdates: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.historyModel = historyModel
        self.monitorState = monitorState
        self.onCopyHistoryItem = onCopyHistoryItem
        self.onShowHistory = onShowHistory
        self.onShowFavorites = onShowFavorites
        self.onShowHelp = onShowHelp
        self.onTogglePause = onTogglePause
        self.onClearHistory = onClearHistory
        self.onShowSettings = onShowSettings
        self.canCheckForUpdates = canCheckForUpdates
        self.onCheckForUpdates = onCheckForUpdates
        self.onQuit = onQuit
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: Self.statusItemLength)
        statusItem = item

        if let button = item.button {
            if let icon = Self.makeMenuBarIcon() {
                button.image = icon
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                button.image = nil
                button.imagePosition = .noImage
                button.title = "MacClipy"
            }
            button.toolTip = "MacClipy"
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        rebuild()
    }

    private static func makeMenuBarIcon() -> NSImage? {
        guard let image = NSImage(systemSymbolName: menuBarIconSymbolName, accessibilityDescription: "MacClipy") else {
            return nil
        }

        image.isTemplate = true
        return image
    }

    func menuNeedsUpdate(_: NSMenu) {
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

        let helpHotKeyItem = NSMenuItem(
            title: L10n.tr("menu.helpHotKey", shortcutDisplayName(for: .showHelp)),
            action: nil,
            keyEquivalent: ""
        )
        helpHotKeyItem.isEnabled = false
        menu.addItem(helpHotKeyItem)

        if monitorState() {
            let pausedItem = NSMenuItem(title: L10n.tr("menu.pauseStatus"), action: nil, keyEquivalent: "")
            pausedItem.isEnabled = false
            menu.addItem(pausedItem)
        }
    }

    private func addCommandItems(to menu: NSMenu) {
        for item in Self.commandItemOrder {
            switch item {
            case .settings:
                let menuItem = NSMenuItem(title: L10n.tr("menu.settings"), action: #selector(showSettings), keyEquivalent: ",")
                menuItem.target = self
                menu.addItem(menuItem)
            case .checkForUpdates:
                let menuItem = NSMenuItem(
                    title: L10n.tr("menu.checkForUpdates"),
                    action: #selector(checkForUpdates),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.isEnabled = canCheckForUpdates()
                menu.addItem(menuItem)
            case .help:
                let menuItem = NSMenuItem(title: L10n.tr("menu.keyboardHelp"), action: #selector(showHelp), keyEquivalent: "/")
                menuItem.keyEquivalentModifierMask = [.command, .shift]
                menuItem.target = self
                menu.addItem(menuItem)
            case .search:
                let menuItem = NSMenuItem(title: L10n.tr("menu.search"), action: #selector(showHistory), keyEquivalent: "")
                menuItem.target = self
                menu.addItem(menuItem)
            case .favorites:
                let menuItem = NSMenuItem(title: L10n.tr("menu.favorites"), action: #selector(showFavorites), keyEquivalent: "")
                menuItem.target = self
                menu.addItem(menuItem)
            case .pause:
                let title = monitorState() ? L10n.tr("menu.pauseResume") : L10n.tr("menu.pauseStart")
                let menuItem = NSMenuItem(title: title, action: #selector(togglePause), keyEquivalent: "")
                menuItem.target = self
                menu.addItem(menuItem)
            case .clearHistory:
                let menuItem = NSMenuItem(title: L10n.tr("menu.clearHistory"), action: #selector(clearHistory), keyEquivalent: "")
                menuItem.target = self
                menuItem.isEnabled = !historyModel.items.isEmpty
                menu.addItem(menuItem)
            case .separator:
                menu.addItem(.separator())
            case .quit:
                let menuItem = NSMenuItem(title: L10n.tr("menu.quit"), action: #selector(quit), keyEquivalent: "q")
                menuItem.target = self
                menu.addItem(menuItem)
            }
        }
    }

    private func shortcutDisplayName(for name: KeyboardShortcuts.Name) -> String {
        KeyboardShortcutDisplay.displayName(for: name)
    }

    @objc private func copyMenuItem(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let item = historyModel.items.first(where: { $0.id == id })
        else {
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

    @objc private func showHelp() {
        onShowHelp()
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

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    @objc private func quit() {
        onQuit()
    }
}
