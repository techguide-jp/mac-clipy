import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipboardStore()
    private let settingsStore = SettingsStore()

    private var monitor: ClipboardMonitor!
    private var hotKeyController: HotKeyController?
    private var statusItem: NSStatusItem!
    private var previousApplication: NSRunningApplication?

    private lazy var historyPanelController = HistoryPanelController(store: store) { [weak self] item in
        self?.copyAndPaste(item)
    }

    private lazy var settingsWindowController = SettingsWindowController(
        settingsStore: settingsStore,
        onSave: { [weak self] in
            self?.setupHotKey()
            self?.rebuildStatusMenu()
        },
        onDismiss: { [weak self] in
            self?.setupHotKey()
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            try settingsStore.load()
            try store.load()
        } catch {
            showAlert(title: "初期化に失敗しました", message: error.localizedDescription)
        }

        monitor = ClipboardMonitor(store: store, settingsStore: settingsStore) { [weak self] in
            self?.rebuildStatusMenu()
            self?.historyPanelController.refresh()
        }
        monitor.start()

        setupStatusItem()
        setupHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        hotKeyController?.unregister()
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
        statusItem = NSStatusBar.system.statusItem(withLength: 84)
        if let button = statusItem.button {
            button.image = nil
            button.imagePosition = .noImage
            button.title = "MacClipy"
            button.toolTip = "MacClipy"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildStatusMenu()
    }

    private func setupHotKey() {
        hotKeyController?.unregister()

        let controller = HotKeyController(shortcut: settingsStore.settings.hotKey) { [weak self] in
            self?.showHistoryContextMenu()
        }

        do {
            try controller.register()
            hotKeyController = controller
        } catch {
            showAlert(title: "ホットキー登録に失敗しました", message: error.localizedDescription)
        }
    }

    private func rebuildStatusMenu() {
        guard let menu = statusItem?.menu else {
            return
        }

        menu.removeAllItems()

        if store.items.isEmpty {
            let emptyItem = NSMenuItem(title: "履歴はありません", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, item) in store.items.prefix(10).enumerated() {
                let menuItem = NSMenuItem(
                    title: "\(index + 1). \(item.menuTitle)",
                    action: #selector(copyMenuItem(_:)),
                    keyEquivalent: index < 9 ? "\(index + 1)" : ""
                )
                menuItem.target = self
                menuItem.representedObject = item.id.uuidString
                menu.addItem(menuItem)
            }
        }

        menu.addItem(.separator())

        let hotKeyItem = NSMenuItem(title: "履歴メニュー: \(settingsStore.settings.hotKey.displayName)", action: nil, keyEquivalent: "")
        hotKeyItem.isEnabled = false
        menu.addItem(hotKeyItem)

        let searchItem = NSMenuItem(title: "検索...", action: #selector(showHistoryPanel), keyEquivalent: "")
        searchItem.target = self
        menu.addItem(searchItem)

        let pauseTitle = monitor?.isPaused == true ? "監視を再開" : "監視を一時停止"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        let settingsItem = NSMenuItem(title: "設定...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let clearItem = NSMenuItem(title: "履歴を削除...", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = !store.items.isEmpty
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func copyMenuItem(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let item = store.items.first(where: { $0.id == id }) else {
            return
        }

        do {
            try monitor.copyToPasteboard(item)
        } catch {
            showAlert(title: "コピーに失敗しました", message: error.localizedDescription)
        }
    }

    @objc private func pasteMenuItem(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString),
              let item = store.items.first(where: { $0.id == id }) else {
            return
        }

        copyAndPaste(item)
    }

    @objc private func showHistoryContextMenu() {
        rememberFrontmostApplication()

        let menu = NSMenu()
        menu.autoenablesItems = false

        if store.items.isEmpty {
            let emptyItem = NSMenuItem(title: "履歴はありません", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, item) in store.items.prefix(20).enumerated() {
                let menuItem = NSMenuItem(
                    title: "\(index + 1). \(item.menuTitle)",
                    action: #selector(pasteMenuItem(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = item.id.uuidString
                menuItem.toolTip = item.content
                menu.addItem(menuItem)
            }
        }

        menu.addItem(.separator())

        let searchItem = NSMenuItem(title: "検索ウィンドウを開く...", action: #selector(showHistoryPanel), keyEquivalent: "")
        searchItem.target = self
        menu.addItem(searchItem)

        let settingsItem = NSMenuItem(title: "設定...", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let location = NSEvent.mouseLocation
        menu.popUp(positioning: menu.items.first, at: location, in: nil)
    }

    @objc private func showHistoryPanel() {
        rememberFrontmostApplication()
        historyPanelController.show()
    }

    @objc private func togglePause() {
        monitor.setPaused(!monitor.isPaused)
        rebuildStatusMenu()
    }

    @objc private func showSettings() {
        hotKeyController?.unregister()
        settingsWindowController.show()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "履歴を削除しますか？"
        alert.informativeText = "保存済みのクリップボード履歴をすべて削除します。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            try store.clear()
            rebuildStatusMenu()
            historyPanelController.refresh()
        } catch {
            showAlert(title: "履歴削除に失敗しました", message: error.localizedDescription)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func copyAndPaste(_ item: ClipboardItem) {
        do {
            try monitor.copyToPasteboard(item)
            let pasted = PasteController.pasteIntoPreviousApplication(previousApplication)
            if !pasted {
                showAlert(
                    title: "コピーしました",
                    message: "貼り付けにはアクセシビリティ権限が必要です。システム設定で MacClipy を許可してください。"
                )
            }
        } catch {
            showAlert(title: "貼り付けに失敗しました", message: error.localizedDescription)
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
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
