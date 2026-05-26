import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipboardStore()
    private let favoriteStore = FavoriteStore()
    private let settingsStore = SettingsStore()

    private var monitor: ClipboardMonitor?
    private var historyHotKeyController: HotKeyController?
    private var favoriteHotKeyController: HotKeyController?
    private var statusItem: NSStatusItem?
    private var previousApplication: NSRunningApplication?

    private lazy var historyPanelController = HistoryPanelController(store: store) { [weak self] item in
        self?.copyAndPaste(item)
    }

    private lazy var historyPopupController = HistoryPopupController(
        store: store,
        favoriteStore: favoriteStore,
        onItemChosen: { [weak self] item in
            self?.copyAndPaste(item)
        },
        onSettingsRequested: { [weak self] in
            self?.showSettings()
        }
    )

    private lazy var settingsWindowController = SettingsWindowController(
        settingsStore: settingsStore,
        favoriteStore: favoriteStore,
        onSave: { [weak self] in
            guard let self else {
                return
            }

            try self.setupHotKeys()
            self.rebuildStatusMenu()
        },
        onDismiss: { [weak self] in
            self?.restoreHotKeysAfterSettings()
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            try settingsStore.load()
            try store.load()
            try favoriteStore.load()
        } catch {
            showAlert(title: L10n.tr("alert.initializationFailed.title"), message: error.localizedDescription)
        }

        monitor = ClipboardMonitor(store: store, settingsStore: settingsStore) { [weak self] in
            self?.rebuildStatusMenu()
            self?.historyPanelController.refresh()
        }
        monitor?.start()

        setupStatusItem()
        do {
            try setupHotKeys()
        } catch {
            showAlert(title: L10n.tr("alert.hotKeyRegistrationFailed.title"), message: error.localizedDescription)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        historyHotKeyController?.unregister()
        favoriteHotKeyController?.unregister()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rememberFrontmostApplication()
        rebuildStatusMenu()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHistoryPanel()
        return true
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 84)
        statusItem = item

        if let button = item.button {
            button.image = nil
            button.imagePosition = NSControl.ImagePosition.noImage
            button.title = "MacClipy"
            button.toolTip = "MacClipy"
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        rebuildStatusMenu()
    }

    private func setupHotKeys() throws {
        let previousHistoryController = historyHotKeyController
        let previousFavoriteController = favoriteHotKeyController
        var registeredControllers: [HotKeyController] = []

        do {
            let historyController = try preparedHotKeyController(
                currentController: previousHistoryController,
                shortcut: settingsStore.settings.hotKey,
                identifier: 1,
                registeredControllers: &registeredControllers
            ) { [weak self] in
                self?.showHistoryPopup()
            }
            let favoriteController = try preparedHotKeyController(
                currentController: previousFavoriteController,
                shortcut: settingsStore.settings.favoriteHotKey,
                identifier: 2,
                registeredControllers: &registeredControllers
            ) { [weak self] in
                self?.showFavoritePopup()
            }

            if historyController !== previousHistoryController {
                previousHistoryController?.unregister()
            }
            if favoriteController !== previousFavoriteController {
                previousFavoriteController?.unregister()
            }

            historyHotKeyController = historyController
            favoriteHotKeyController = favoriteController
        } catch {
            registeredControllers.forEach { $0.unregister() }
            throw error
        }
    }

    private func preparedHotKeyController(
        currentController: HotKeyController?,
        shortcut: KeyboardShortcut,
        identifier: UInt32,
        registeredControllers: inout [HotKeyController],
        onPressed: @MainActor @escaping () -> Void
    ) throws -> HotKeyController {
        if let currentController, currentController.shortcut == shortcut {
            if !currentController.isRegistered {
                try currentController.register()
            }
            return currentController
        }

        let controller = HotKeyController(shortcut: shortcut, identifier: identifier, onPressed: onPressed)
        try controller.register()
        registeredControllers.append(controller)
        return controller
    }

    private func restoreHotKeysAfterSettings() {
        do {
            try setupHotKeys()
        } catch {
            showAlert(title: L10n.tr("alert.hotKeyRegistrationFailed.title"), message: error.localizedDescription)
        }
    }

    private func rebuildStatusMenu() {
        guard let menu = statusItem?.menu else {
            return
        }

        menu.removeAllItems()

        if store.items.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.tr("menu.emptyHistory"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, item) in store.items.prefix(10).enumerated() {
                let menuItem = NSMenuItem(title: "\(index + 1). \(item.menuTitle)",
                                          action: #selector(copyMenuItem(_:)),
                                          keyEquivalent: index < 9 ? "\(index + 1)" : "")
                menuItem.target = self
                menuItem.representedObject = item.id.uuidString
                menu.addItem(menuItem)
            }
        }

        menu.addItem(.separator())

        let hotKeyItem = NSMenuItem(title: L10n.tr("menu.hotKey", settingsStore.settings.hotKey.displayName),
                                    action: nil,
                                    keyEquivalent: "")
        hotKeyItem.isEnabled = false
        menu.addItem(hotKeyItem)

        let favoriteHotKeyItem = NSMenuItem(
            title: L10n.tr("menu.favoriteHotKey", settingsStore.settings.favoriteHotKey.displayName),
            action: nil,
            keyEquivalent: ""
        )
        favoriteHotKeyItem.isEnabled = false
        menu.addItem(favoriteHotKeyItem)

        let searchItem = NSMenuItem(title: L10n.tr("menu.search"),
                                    action: #selector(showHistoryPanel),
                                    keyEquivalent: "")
        searchItem.target = self
        menu.addItem(searchItem)

        if monitor?.isPaused == true {
            let pausedItem = NSMenuItem(title: L10n.tr("menu.pauseStatus"), action: nil, keyEquivalent: "")
            pausedItem.isEnabled = false
            menu.addItem(pausedItem)
        }

        let pauseTitle = monitor?.isPaused == true ? L10n.tr("menu.pauseResume") : L10n.tr("menu.pauseStart")
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        let settingsItem = NSMenuItem(title: L10n.tr("menu.settings"),
                                      action: #selector(showSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let clearItem = NSMenuItem(title: L10n.tr("menu.clearHistory"),
                                   action: #selector(clearHistory),
                                   keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = !store.items.isEmpty
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.tr("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func copyMenuItem(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let item = store.items.first(where: { $0.id == id }) else {
            return
        }

        copyAndPaste(item)
    }

    @objc private func showHistoryPopup() {
        rememberFrontmostApplication()
        historyPopupController.show(at: NSEvent.mouseLocation, initialMode: .all)
    }

    @objc private func showFavoritePopup() {
        rememberFrontmostApplication()
        historyPopupController.show(at: NSEvent.mouseLocation, initialMode: .favorites)
    }

    @objc private func showHistoryPanel() {
        rememberFrontmostApplication()
        historyPanelController.show()
    }

    @objc private func togglePause() {
        guard let monitor else {
            return
        }

        monitor.setPaused(!monitor.isPaused)
        rebuildStatusMenu()
    }

    @objc private func showSettings() {
        historyHotKeyController?.unregister()
        favoriteHotKeyController?.unregister()
        settingsWindowController.show()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("alert.clearHistory.title")
        alert.informativeText = L10n.tr("alert.clearHistory.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.tr("button.deleteHistoryOnly"))
        alert.addButton(withTitle: L10n.tr("button.deleteHistoryAndFavorites"))
        alert.addButton(withTitle: L10n.tr("button.cancel"))

        let response = alert.runModal()

        do {
            switch response {
            case .alertFirstButtonReturn:
                try store.clear()
            case .alertSecondButtonReturn:
                try store.clear()
                try favoriteStore.clear()
                historyPopupController.refresh()
            default:
                return
            }
            rebuildStatusMenu()
            historyPanelController.refresh()
        } catch {
            showAlert(title: L10n.tr("alert.clearHistoryFailed.title"), message: error.localizedDescription)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func copyAndPaste(_ item: ClipboardItem) {
        guard let monitor else {
            return
        }

        do {
            try monitor.copyToPasteboard(item)
            let pasted = PasteController.pasteIntoPreviousApplication(previousApplication)
            if !pasted {
                showAlert(
                    title: L10n.tr("alert.copy.title"),
                    message: L10n.tr("alert.accessibilityPermission.message")
                )
            }
        } catch {
            showAlert(title: L10n.tr("alert.pasteFailed.title"), message: error.localizedDescription)
        }
    }

    private func rememberFrontmostApplication() {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return
        }

        if frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = frontmostApplication
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.tr("button.ok"))
        alert.runModal()
    }
}
