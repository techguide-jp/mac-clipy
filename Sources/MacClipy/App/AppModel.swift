import AppKit
import KeyboardShortcuts
import Observation

@MainActor
@Observable
final class AppModel {
    private struct ClipboardSourceContext {
        let bundleIdentifier: String?
        let canCaptureNow: Bool
    }

    let settingsModel = SettingsModel()
    let historyModel = ClipboardHistoryModel()
    let favoritesModel = FavoritesModel()
    let historyPopupModel: HistoryPopupModel
    let appUpdater = AppUpdater()

    private var monitor: ClipboardMonitor?
    private var statusItemController: StatusItemController?
    private var floatingPanelController: FloatingPanelController?
    @ObservationIgnored private var settingsWindowController: SettingsWindowController?
    @ObservationIgnored private var onboardingWindowController: OnboardingWindowController?
    @ObservationIgnored private let developmentCrashReporter = DevelopmentCrashReporter()
    private var previousApplication: NSRunningApplication?
    var isKeyboardHelpPresented = false
    var developmentCrashReport: DevelopmentCrashReport?

    var isPaused: Bool {
        monitor?.isPaused == true
    }

    init() {
        let popupModel = HistoryPopupModel(historyModel: historyModel, favoritesModel: favoritesModel)
        historyPopupModel = popupModel
        popupModel.onChoose = { [weak self] item in
            self?.copyAndPaste(item)
        }
        popupModel.onSettingsRequested = { [weak self] in
            self?.showSettings()
        }
        popupModel.onHelpRequested = { [weak self] in
            self?.showKeyboardHelp()
        }
        settingsWindowController = SettingsWindowController(appModel: self)
        onboardingWindowController = OnboardingWindowController(
            isAccessibilityTrusted: { PasteController.isAccessibilityTrusted },
            requestAccessibilityPermission: { PasteController.requestAccessibilityPermission() },
            onDismiss: { OnboardingState.markCompleted() }
        )
    }

    func applicationDidFinishLaunching() {
        NSApp.setActivationPolicy(.accessory)
        let previousCrashReport = developmentCrashReporter.startLaunch()
        let shouldShowOnboarding = OnboardingState.shouldPresentAtLaunch()

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

        if shouldShowOnboarding {
            showOnboarding()
        } else if let previousCrashReport {
            showDevelopmentCrashReport(previousCrashReport)
        }
    }

    func applicationWillTerminate() {
        monitor?.stop()
        developmentCrashReporter.markCleanTermination()
    }

    func showHistoryPopup() {
        let clipboardSource = rememberFrontmostApplication()
        syncCurrentClipboard(from: clipboardSource)
        floatingPanelController?.show(at: NSEvent.mouseLocation, initialMode: .all)
    }

    func showFavoritePopup() {
        let clipboardSource = rememberFrontmostApplication()
        syncCurrentClipboard(from: clipboardSource)
        floatingPanelController?.show(at: NSEvent.mouseLocation, initialMode: .favorites)
    }

    func showSettings() {
        settingsWindowController?.show()
    }

    func showKeyboardHelp() {
        floatingPanelController?.close()
        developmentCrashReport = nil
        settingsWindowController?.showKeyboardHelp()
    }

    func showOnboarding() {
        floatingPanelController?.close()
        onboardingWindowController?.show()
    }

    func checkForUpdates() {
        appUpdater.checkForUpdates()
    }

    func showDevelopmentCrashReport(_ report: DevelopmentCrashReport) {
        floatingPanelController?.close()
        isKeyboardHelpPresented = false
        settingsWindowController?.show()
        developmentCrashReport = report
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
                historyModel.refreshFromStore()
                floatingPanelController?.refresh()
                refreshStatusMenu()
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
            onShowHelp: { [weak self] in self?.showKeyboardHelp() },
            onShowOnboarding: { [weak self] in self?.showOnboarding() },
            onTogglePause: { [weak self] in self?.togglePause() },
            onClearHistory: { [weak self] in self?.clearHistory() },
            onShowSettings: { [weak self] in self?.showSettings() },
            canCheckForUpdates: { [weak self] in self?.appUpdater.canCheckForUpdates == true },
            onCheckForUpdates: { [weak self] in self?.checkForUpdates() },
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

        KeyboardShortcuts.onKeyUp(for: .showHelp) { [weak self] in
            Task { @MainActor in
                self?.showKeyboardHelp()
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

    private func syncCurrentClipboard(from source: ClipboardSourceContext) {
        if source.canCaptureNow {
            monitor?.captureCurrentPasteboardIfNeeded(sourceBundleID: source.bundleIdentifier)
        }
        historyModel.refreshFromStore()
    }

    @discardableResult
    private func rememberFrontmostApplication() -> ClipboardSourceContext {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return ClipboardSourceContext(bundleIdentifier: nil, canCaptureNow: false)
        }

        if frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = frontmostApplication
            return ClipboardSourceContext(bundleIdentifier: frontmostApplication.bundleIdentifier, canCaptureNow: true)
        }

        return ClipboardSourceContext(bundleIdentifier: nil, canCaptureNow: false)
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
