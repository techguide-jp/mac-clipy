import AppKit
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let onSave: () throws -> Void
    private let onDismiss: () -> Void
    private let shortcutRecorder = ShortcutRecorderControl(shortcut: .defaultShortcut)
    private let excludedAppsTableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var excludedBundleIdentifiers: [String] = []

    init(settingsStore: SettingsStore, onSave: @escaping () throws -> Void, onDismiss: @escaping () -> Void) {
        self.settingsStore = settingsStore
        self.onSave = onSave
        self.onDismiss = onDismiss

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("settings.title")
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        buildInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        shortcutRecorder.shortcut = settingsStore.settings.hotKey
        excludedBundleIdentifiers = settingsStore.settings.excludedBundleIdentifiers
        excludedAppsTableView.reloadData()
        statusLabel.stringValue = ""

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(shortcutRecorder)
        }
    }

    private func buildInterface() {
        guard let window else {
            return
        }

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let shortcutLabel = NSTextField(labelWithString: L10n.tr("settings.shortcut.title"))
        shortcutLabel.font = .boldSystemFont(ofSize: 13)
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false

        let shortcutHelpLabel = NSTextField(
            labelWithString: L10n.tr("settings.shortcut.help")
        )
        shortcutHelpLabel.textColor = .secondaryLabelColor
        shortcutHelpLabel.font = .systemFont(ofSize: 12)
        shortcutHelpLabel.translatesAutoresizingMaskIntoConstraints = false

        shortcutRecorder.onMessage = { [weak self] message in
            self?.statusLabel.stringValue = message
        }
        shortcutRecorder.translatesAutoresizingMaskIntoConstraints = false

        let resetShortcutButton = NSButton(title: L10n.tr("settings.shortcut.reset"),
                                           target: self,
                                           action: #selector(resetShortcut))
        resetShortcutButton.bezelStyle = .rounded
        resetShortcutButton.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: L10n.tr("settings.excludedApps.title"))
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let excludedAppsHelpLabel = NSTextField(
            labelWithString: L10n.tr("settings.excludedApps.help")
        )
        excludedAppsHelpLabel.textColor = .secondaryLabelColor
        excludedAppsHelpLabel.font = .systemFont(ofSize: 12)
        excludedAppsHelpLabel.translatesAutoresizingMaskIntoConstraints = false

        let excludedAppsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("excludedApp"))
        excludedAppsColumn.title = L10n.tr("settings.excludedApps.column")
        excludedAppsColumn.resizingMask = .autoresizingMask
        excludedAppsTableView.addTableColumn(excludedAppsColumn)
        excludedAppsTableView.headerView = nil
        excludedAppsTableView.delegate = self
        excludedAppsTableView.dataSource = self
        excludedAppsTableView.rowHeight = 30
        excludedAppsTableView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.documentView = excludedAppsTableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let addExcludedAppButton = NSButton(title: L10n.tr("settings.excludedApps.add"),
                                            target: self,
                                            action: #selector(addExcludedApp))
        addExcludedAppButton.bezelStyle = .rounded
        addExcludedAppButton.translatesAutoresizingMaskIntoConstraints = false

        let removeExcludedAppButton = NSButton(title: L10n.tr("settings.excludedApps.remove"),
                                               target: self,
                                               action: #selector(removeSelectedExcludedApp))
        removeExcludedAppButton.bezelStyle = .rounded
        removeExcludedAppButton.translatesAutoresizingMaskIntoConstraints = false

        let resetExcludedAppsButton = NSButton(title: L10n.tr("settings.excludedApps.reset"),
                                               target: self,
                                               action: #selector(resetExcludedApps))
        resetExcludedAppsButton.bezelStyle = .rounded
        resetExcludedAppsButton.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: L10n.tr("button.save"), target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: L10n.tr("button.cancel"), target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let layoutViews = SettingsLayoutViews(
            shortcutLabel: shortcutLabel,
            shortcutHelpLabel: shortcutHelpLabel,
            shortcutRecorder: shortcutRecorder,
            resetShortcutButton: resetShortcutButton,
            titleLabel: titleLabel,
            excludedAppsHelpLabel: excludedAppsHelpLabel,
            scrollView: scrollView,
            addExcludedAppButton: addExcludedAppButton,
            removeExcludedAppButton: removeExcludedAppButton,
            resetExcludedAppsButton: resetExcludedAppsButton,
            statusLabel: statusLabel,
            saveButton: saveButton,
            cancelButton: cancelButton
        )
        layoutViews.subviews.forEach(contentView.addSubview)
        activateLayout(layoutViews, in: contentView)
    }

    private func activateLayout(_ views: SettingsLayoutViews, in contentView: NSView) {
        NSLayoutConstraint.activate([
            views.shortcutLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            views.shortcutLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            views.shortcutLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            views.shortcutHelpLabel.topAnchor.constraint(equalTo: views.shortcutLabel.bottomAnchor, constant: 4),
            views.shortcutHelpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            views.shortcutHelpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            views.shortcutRecorder.topAnchor.constraint(equalTo: views.shortcutHelpLabel.bottomAnchor, constant: 8),
            views.shortcutRecorder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            views.shortcutRecorder.trailingAnchor.constraint(equalTo: views.resetShortcutButton.leadingAnchor, constant: -10),
            views.shortcutRecorder.heightAnchor.constraint(equalToConstant: 54),

            views.resetShortcutButton.centerYAnchor.constraint(equalTo: views.shortcutRecorder.centerYAnchor),
            views.resetShortcutButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            views.resetShortcutButton.widthAnchor.constraint(equalToConstant: 96),

            views.titleLabel.topAnchor.constraint(equalTo: views.shortcutRecorder.bottomAnchor, constant: 16),
            views.titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            views.titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            views.excludedAppsHelpLabel.topAnchor.constraint(equalTo: views.titleLabel.bottomAnchor, constant: 4),
            views.excludedAppsHelpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            views.excludedAppsHelpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            views.scrollView.topAnchor.constraint(equalTo: views.excludedAppsHelpLabel.bottomAnchor, constant: 8),
            views.scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            views.scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            views.scrollView.bottomAnchor.constraint(equalTo: views.addExcludedAppButton.topAnchor, constant: -10),

            views.addExcludedAppButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            views.addExcludedAppButton.bottomAnchor.constraint(equalTo: views.statusLabel.topAnchor, constant: -10),

            views.removeExcludedAppButton.leadingAnchor.constraint(
                equalTo: views.addExcludedAppButton.trailingAnchor,
                constant: 8
            ),
            views.removeExcludedAppButton.centerYAnchor.constraint(equalTo: views.addExcludedAppButton.centerYAnchor),

            views.resetExcludedAppsButton.leadingAnchor.constraint(
                equalTo: views.removeExcludedAppButton.trailingAnchor,
                constant: 8
            ),
            views.resetExcludedAppsButton.centerYAnchor.constraint(equalTo: views.addExcludedAppButton.centerYAnchor),
            views.resetExcludedAppsButton.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -16
            ),

            views.statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            views.statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: views.cancelButton.leadingAnchor, constant: -12),
            views.statusLabel.centerYAnchor.constraint(equalTo: views.saveButton.centerYAnchor),

            views.cancelButton.trailingAnchor.constraint(equalTo: views.saveButton.leadingAnchor, constant: -8),
            views.cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            views.saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            views.saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    @objc private func save() {
        let previousSettings = settingsStore.settings

        do {
            try settingsStore.update(excludedBundleIdentifiers: excludedBundleIdentifiers,
                                     hotKey: shortcutRecorder.shortcut)

            do {
                try onSave()
            } catch {
                try rollbackSettings(to: previousSettings)
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

    @objc private func cancel() {
        window?.orderOut(nil)
        onDismiss()
    }

    @objc private func resetShortcut() {
        shortcutRecorder.shortcut = .defaultShortcut
        statusLabel.stringValue = L10n.tr(
            "settings.status.shortcutWillActivate",
            KeyboardShortcut.defaultShortcut.displayName
        )
        window?.makeFirstResponder(shortcutRecorder)
    }

    @objc private func addExcludedApp() {
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

    @objc private func removeSelectedExcludedApp() {
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

    @objc private func resetExcludedApps() {
        excludedBundleIdentifiers = AppSettings.defaultExcludedBundleIdentifiers
        excludedAppsTableView.reloadData()
        statusLabel.stringValue = L10n.tr("settings.status.excludedAppsWillReset")
    }

    private func presentExcludedAppPanel(_ panel: NSOpenPanel) {
        guard panel.runModal() == .OK else {
            return
        }

        appendExcludedApp(from: panel.url)
    }

    private func rollbackSettings(to previousSettings: AppSettings) throws {
        try settingsStore.update(
            excludedBundleIdentifiers: previousSettings.excludedBundleIdentifiers,
            hotKey: previousSettings.hotKey
        )
        excludedBundleIdentifiers = previousSettings.excludedBundleIdentifiers
        shortcutRecorder.shortcut = previousSettings.hotKey
        excludedAppsTableView.reloadData()
    }

    private func appendExcludedApp(from appURL: URL?) {
        guard let appURL, let bundle = Bundle(url: appURL), let bundleIdentifier = bundle.bundleIdentifier else {
            statusLabel.stringValue = L10n.tr("settings.status.appReadFailed")
            return
        }

        if excludedBundleIdentifiers.contains(where: { $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame }) {
            statusLabel.stringValue = L10n.tr(
                "settings.status.appAlreadyAdded",
                displayName(for: bundleIdentifier)
            )
            return
        }

        excludedBundleIdentifiers.append(bundleIdentifier)
        excludedBundleIdentifiers = AppSettings.normalizedBundleIdentifiers(excludedBundleIdentifiers)
        excludedAppsTableView.reloadData()
        statusLabel.stringValue = L10n.tr(
            "settings.status.appWillBeExcluded",
            displayName(for: bundleIdentifier)
        )
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onDismiss()
    }
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        excludedBundleIdentifiers.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard excludedBundleIdentifiers.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("excludedAppCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? ExcludedAppCellView(identifier: identifier)

        let bundleIdentifier = excludedBundleIdentifiers[row]
        cell.textField?.stringValue = displayName(for: bundleIdentifier)
        cell.toolTip = bundleIdentifier
        return cell
    }
}

private extension SettingsWindowController {
    func displayName(for bundleIdentifier: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let bundle = Bundle(url: appURL) {
            return appDisplayName(from: bundle, fallbackURL: appURL)
        }

        if bundleIdentifier.caseInsensitiveCompare(Bundle.main.bundleIdentifier ?? "") == .orderedSame {
            return "MacClipy"
        }

        if let localizationKey = Self.knownAppNameKeys[bundleIdentifier.lowercased()] {
            return L10n.tr(localizationKey)
        }

        return bundleIdentifier
    }

    func appDisplayName(from bundle: Bundle, fallbackURL: URL) -> String {
        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }

        if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !bundleName.isEmpty {
            return bundleName
        }

        return fallbackURL.deletingPathExtension().lastPathComponent
    }

    static let knownAppNameKeys = [
        "com.1password.1password": "appName.1password",
        "com.agilebits.onepassword7": "appName.1password7",
        "com.bitwarden.desktop": "appName.bitwarden",
        "org.keepassxc.keepassxc": "appName.keepassxc",
        "com.apple.keychainaccess": "appName.keychainAccess",
        "com.local.macclipy": "appName.macclipy"
    ]
}

private struct SettingsLayoutViews {
    let shortcutLabel: NSTextField
    let shortcutHelpLabel: NSTextField
    let shortcutRecorder: ShortcutRecorderControl
    let resetShortcutButton: NSButton
    let titleLabel: NSTextField
    let excludedAppsHelpLabel: NSTextField
    let scrollView: NSScrollView
    let addExcludedAppButton: NSButton
    let removeExcludedAppButton: NSButton
    let resetExcludedAppsButton: NSButton
    let statusLabel: NSTextField
    let saveButton: NSButton
    let cancelButton: NSButton

    var subviews: [NSView] {
        [
            shortcutLabel,
            shortcutHelpLabel,
            shortcutRecorder,
            resetShortcutButton,
            titleLabel,
            excludedAppsHelpLabel,
            scrollView,
            addExcludedAppButton,
            removeExcludedAppButton,
            resetExcludedAppsButton,
            statusLabel,
            saveButton,
            cancelButton
        ]
    }
}

private final class ExcludedAppCellView: NSTableCellView {
    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier

        let textField = NSTextField(labelWithString: "")
        textField.font = .systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textField)
        self.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
