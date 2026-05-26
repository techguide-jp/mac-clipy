import AppKit
import UniformTypeIdentifiers

private enum SettingsWindowMetrics {
    static let initialSize = NSSize(width: 780, height: 540)
    static let minimumSize = NSSize(width: 760, height: 520)
}

@MainActor
final class SettingsWindowController: NSWindowController {
    enum FavoriteFolderFilter: Equatable {
        case all
        case unclassified
        case folder(UUID)
    }

    enum FavoriteFolderTableRows {
        static let all = 0
        static let unclassified = 1
        static let concreteFolderOffset = 2
    }

    enum FavoriteFolderMoveOffset {
        static let up = -1
        static let down = 1
    }

    let settingsStore: SettingsStore
    let favoriteStore: FavoriteStore
    let onSave: () throws -> Void
    let onDismiss: () -> Void

    let shortcutRecorder = ShortcutRecorderControl(shortcut: .defaultShortcut)
    let favoriteShortcutRecorder = ShortcutRecorderControl(shortcut: .defaultFavoriteShortcut)
    let excludedAppsTableView = NSTableView()
    let favoriteFoldersTableView = NSTableView()
    let favoriteItemsTableView = NSTableView()
    let favoriteSortPopup = NSPopUpButton()
    let folderAssignmentPopup = NSPopUpButton()
    let statusLabel = NSTextField(labelWithString: "")

    var excludedBundleIdentifiers: [String] = []
    var favoriteRows: [FavoriteItem] = []

    init(
        settingsStore: SettingsStore,
        favoriteStore: FavoriteStore,
        onSave: @escaping () throws -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.favoriteStore = favoriteStore
        self.onSave = onSave
        self.onDismiss = onDismiss

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsWindowMetrics.initialSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("settings.title")
        window.isReleasedWhenClosed = false
        window.minSize = SettingsWindowMetrics.minimumSize

        super.init(window: window)
        window.delegate = self
        buildInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        shortcutRecorder.shortcut = settingsStore.settings.hotKey
        favoriteShortcutRecorder.shortcut = settingsStore.settings.favoriteHotKey
        excludedBundleIdentifiers = settingsStore.settings.excludedBundleIdentifiers
        excludedAppsTableView.reloadData()
        reloadFavoriteManagement()
        statusLabel.stringValue = ""

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(shortcutRecorder)
        }
    }

    @objc func save() {
        let previousSettings = settingsStore.settings

        do {
            try settingsStore.update(
                excludedBundleIdentifiers: excludedBundleIdentifiers,
                hotKey: shortcutRecorder.shortcut,
                favoriteHotKey: favoriteShortcutRecorder.shortcut
            )

            do {
                try onSave()
            } catch {
                try rollbackSettings(to: previousSettings)
                try? onSave()
                statusLabel.stringValue = L10n.tr(
                    "settings.status.shortcutRegistrationFailed",
                    error.localizedDescription
                )
                return
            }

            statusLabel.stringValue = L10n.tr("settings.status.saved")
            window?.orderOut(nil)
        } catch {
            statusLabel.stringValue = L10n.tr("settings.status.saveFailed", error.localizedDescription)
        }
    }

    @objc func cancel() {
        window?.orderOut(nil)
        onDismiss()
    }

    @objc func resetShortcut() {
        shortcutRecorder.shortcut = .defaultShortcut
        statusLabel.stringValue = L10n.tr(
            "settings.status.shortcutWillActivate",
            KeyboardShortcut.defaultShortcut.displayName
        )
        window?.makeFirstResponder(shortcutRecorder)
    }

    @objc func resetFavoriteShortcut() {
        favoriteShortcutRecorder.shortcut = .defaultFavoriteShortcut
        statusLabel.stringValue = L10n.tr(
            "settings.status.shortcutWillActivate",
            KeyboardShortcut.defaultFavoriteShortcut.displayName
        )
        window?.makeFirstResponder(favoriteShortcutRecorder)
    }

    @objc func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = L10n.tr("settings.openPanel.title")
        panel.prompt = L10n.tr("settings.openPanel.prompt")
        panel.message = L10n.tr("settings.openPanel.message")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]

        guard let window else {
            presentExcludedAppPanel(panel)
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else {
                return
            }

            self?.appendExcludedApp(from: panel.url)
        }
    }

    @objc func removeSelectedExcludedApp() {
        let selectedRow = excludedAppsTableView.selectedRow
        guard excludedBundleIdentifiers.indices.contains(selectedRow) else {
            statusLabel.stringValue = L10n.tr("settings.status.selectAppToRemove")
            return
        }

        let removedName = displayName(for: excludedBundleIdentifiers[selectedRow])
        excludedBundleIdentifiers.remove(at: selectedRow)
        excludedAppsTableView.reloadData()
        statusLabel.stringValue = L10n.tr("settings.status.appWillBeCapturedAgain", removedName)
    }

    @objc func resetExcludedApps() {
        excludedBundleIdentifiers = AppSettings.defaultExcludedBundleIdentifiers
        excludedAppsTableView.reloadData()
        statusLabel.stringValue = L10n.tr("settings.status.excludedAppsWillReset")
    }

    @objc func favoriteFolderSelectionChanged() {
        reloadFavoriteManagement()
    }

    @objc func changeFavoriteSort() {
        reloadFavoriteManagement()
    }

}
