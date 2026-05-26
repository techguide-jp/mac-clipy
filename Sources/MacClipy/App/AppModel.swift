import AppKit
import KeyboardShortcuts
import Observation

@MainActor
@Observable
final class AppModel {
    let settingsModel = SettingsModel()
    let historyModel = ClipboardHistoryModel()
    let favoritesModel = FavoritesModel()

    private(set) var historyPopupModel: HistoryPopupModel!
    private var monitor: ClipboardMonitor?
    private var statusItemController: StatusItemController?
    private var floatingPanelController: FloatingPanelController?
    private var previousApplication: NSRunningApplication?

    var isPaused: Bool {
        monitor?.isPaused == true
    }

    init() {
        let popupModel = HistoryPopupModel(historyModel: historyModel, favoritesModel: favoritesModel)
        popupModel.onChoose = { [weak self] item in
            self?.copyAndPaste(item)
        }
        popupModel.onSettingsRequested = { [weak self] in
            self?.showSettings()
        }
        self.historyPopupModel = popupModel
    }

    func applicationDidFinishLaunching() {
        NSApp.setActivationPolicy(.accessory)

        do {
            try SettingsMigration.migrateIfNeeded()
            settingsModel.reload()
            try historyModel.load()
            try favoritesModel.load()
        } catch {
            showAlert(title: L10n.tr("alert.initializationFailed.title"), message: error.localizedDescription)
        }

        setupClipboardMonitor()
        setupFloatingPanel()
        setupStatusItem()
        setupKeyboardShortcuts()
    }

    func applicationWillTerminate() {
        monitor?.stop()
    }

    func showHistoryPopup() {
        rememberFrontmostApplication()
        floatingPanelController?.show(at: NSEvent.mouseLocation, initialMode: .all)
    }

    func showFavoritePopup() {
        rememberFrontmostApplication()
        floatingPanelController?.show(at: NSEvent.mouseLocation, initialMode: .favorites)
    }

    func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func refreshStatusMenu() {
        statusItemController?.rebuild()
    }

    private func setupClipboardMonitor() {
        monitor = ClipboardMonitor(
            store: historyModel.store,
            excludedBundleIdentifiers: { [weak self] in
                self?.settingsModel.excludedBundleIdentifiers ?? SettingsDefaults.defaultExcludedBundleIdentifiers
            },
            onChange: { [weak self] in
                guard let self else {
                    return
                }
                self.historyModel.refreshFromStore()
                self.floatingPanelController?.refresh()
                self.refreshStatusMenu()
            }
        )
        monitor?.start()
    }

    private func setupFloatingPanel() {
        floatingPanelController = FloatingPanelController(model: historyPopupModel)
    }

    private func setupStatusItem() {
        let controller = StatusItemController(
            historyModel: historyModel,
            monitorState: { [weak self] in self?.isPaused == true },
            onCopyHistoryItem: { [weak self] item in
                self?.rememberFrontmostApplication()
                self?.copyAndPaste(item)
            },
            onShowHistory: { [weak self] in self?.showHistoryPopup() },
            onShowFavorites: { [weak self] in self?.showFavoritePopup() },
            onTogglePause: { [weak self] in self?.togglePause() },
            onClearHistory: { [weak self] in self?.clearHistory() },
            onShowSettings: { [weak self] in self?.showSettings() },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        controller.install()
        statusItemController = controller
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .showHistory) { [weak self] in
            Task { @MainActor in
                self?.showHistoryPopup()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .showFavorites) { [weak self] in
            Task { @MainActor in
                self?.showFavoritePopup()
            }
        }
    }

    private func togglePause() {
        guard let monitor else {
            return
        }

        monitor.setPaused(!monitor.isPaused)
        refreshStatusMenu()
    }

    private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("alert.clearHistory.title")
        alert.informativeText = L10n.tr("alert.clearHistory.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.tr("button.deleteHistoryOnly"))
        alert.addButton(withTitle: L10n.tr("button.deleteHistoryAndFavorites"))
        alert.addButton(withTitle: L10n.tr("button.cancel"))

        do {
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                try historyModel.clear()
            case .alertSecondButtonReturn:
                try historyModel.clear()
                try favoritesModel.store.clear()
                favoritesModel.refreshFromStore()
            default:
                return
            }

            floatingPanelController?.refresh()
            refreshStatusMenu()
        } catch {
            showAlert(title: L10n.tr("alert.clearHistoryFailed.title"), message: error.localizedDescription)
        }
    }

    private func copyAndPaste(_ item: ClipboardItem) {
        guard let monitor else {
            return
        }

        do {
            try monitor.copyToPasteboard(item)
            historyModel.refreshFromStore()
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
