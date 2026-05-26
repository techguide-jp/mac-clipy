import AppKit
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let settingsStore: SettingsStore
    private let onSave: () -> Void
    private let onDismiss: () -> Void
    private let shortcutRecorder = ShortcutRecorderControl(shortcut: .defaultShortcut)
    private let excludedAppsTableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var excludedBundleIdentifiers: [String] = []

    init(settingsStore: SettingsStore, onSave: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.settingsStore = settingsStore
        self.onSave = onSave
        self.onDismiss = onDismiss

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacClipy 設定"
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

        let shortcutLabel = NSTextField(labelWithString: "履歴メニューのショートカット")
        shortcutLabel.font = .boldSystemFont(ofSize: 13)
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false

        let shortcutHelpLabel = NSTextField(
            labelWithString: "枠をクリックしてから、使いたいキーの組み合わせを押します。"
        )
        shortcutHelpLabel.textColor = .secondaryLabelColor
        shortcutHelpLabel.font = .systemFont(ofSize: 12)
        shortcutHelpLabel.translatesAutoresizingMaskIntoConstraints = false

        shortcutRecorder.onMessage = { [weak self] message in
            self?.statusLabel.stringValue = message
        }
        shortcutRecorder.translatesAutoresizingMaskIntoConstraints = false

        let resetShortcutButton = NSButton(title: "既定に戻す", target: self, action: #selector(resetShortcut))
        resetShortcutButton.bezelStyle = .rounded
        resetShortcutButton.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "履歴に保存しないアプリ")
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let excludedAppsHelpLabel = NSTextField(
            labelWithString: "パスワード管理アプリなど、コピー内容を残したくないアプリを選びます。"
        )
        excludedAppsHelpLabel.textColor = .secondaryLabelColor
        excludedAppsHelpLabel.font = .systemFont(ofSize: 12)
        excludedAppsHelpLabel.translatesAutoresizingMaskIntoConstraints = false

        let excludedAppsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("excludedApp"))
        excludedAppsColumn.title = "アプリ"
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

        let addExcludedAppButton = NSButton(title: "アプリを追加...",
                                            target: self,
                                            action: #selector(addExcludedApp))
        addExcludedAppButton.bezelStyle = .rounded
        addExcludedAppButton.translatesAutoresizingMaskIntoConstraints = false

        let removeExcludedAppButton = NSButton(title: "選択項目を削除",
                                               target: self,
                                               action: #selector(removeSelectedExcludedApp))
        removeExcludedAppButton.bezelStyle = .rounded
        removeExcludedAppButton.translatesAutoresizingMaskIntoConstraints = false

        let resetExcludedAppsButton = NSButton(title: "推奨設定に戻す",
                                               target: self,
                                               action: #selector(resetExcludedApps))
        resetExcludedAppsButton.bezelStyle = .rounded
        resetExcludedAppsButton.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: "キャンセル", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(shortcutLabel)
        contentView.addSubview(shortcutHelpLabel)
        contentView.addSubview(shortcutRecorder)
        contentView.addSubview(resetShortcutButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(excludedAppsHelpLabel)
        contentView.addSubview(scrollView)
        contentView.addSubview(addExcludedAppButton)
        contentView.addSubview(removeExcludedAppButton)
        contentView.addSubview(resetExcludedAppsButton)
        contentView.addSubview(statusLabel)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            shortcutLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            shortcutLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            shortcutLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            shortcutHelpLabel.topAnchor.constraint(equalTo: shortcutLabel.bottomAnchor, constant: 4),
            shortcutHelpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            shortcutHelpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            shortcutRecorder.topAnchor.constraint(equalTo: shortcutHelpLabel.bottomAnchor, constant: 8),
            shortcutRecorder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            shortcutRecorder.trailingAnchor.constraint(equalTo: resetShortcutButton.leadingAnchor, constant: -10),
            shortcutRecorder.heightAnchor.constraint(equalToConstant: 54),

            resetShortcutButton.centerYAnchor.constraint(equalTo: shortcutRecorder.centerYAnchor),
            resetShortcutButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            resetShortcutButton.widthAnchor.constraint(equalToConstant: 96),

            titleLabel.topAnchor.constraint(equalTo: shortcutRecorder.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            excludedAppsHelpLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            excludedAppsHelpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            excludedAppsHelpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: excludedAppsHelpLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: addExcludedAppButton.topAnchor, constant: -10),

            addExcludedAppButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            addExcludedAppButton.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -10),

            removeExcludedAppButton.leadingAnchor.constraint(equalTo: addExcludedAppButton.trailingAnchor, constant: 8),
            removeExcludedAppButton.centerYAnchor.constraint(equalTo: addExcludedAppButton.centerYAnchor),

            resetExcludedAppsButton.leadingAnchor.constraint(
                equalTo: removeExcludedAppButton.trailingAnchor,
                constant: 8
            ),
            resetExcludedAppsButton.centerYAnchor.constraint(equalTo: addExcludedAppButton.centerYAnchor),
            resetExcludedAppsButton.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -16
            ),

            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: cancelButton.leadingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),

            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    @objc private func save() {
        do {
            try settingsStore.update(excludedBundleIdentifiers: excludedBundleIdentifiers,
                                     hotKey: shortcutRecorder.shortcut)
            statusLabel.stringValue = "保存しました"
            onSave()
            window?.orderOut(nil)
        } catch {
            statusLabel.stringValue = "保存に失敗しました: \(error.localizedDescription)"
        }
    }

    @objc private func cancel() {
        window?.orderOut(nil)
        onDismiss()
    }

    @objc private func resetShortcut() {
        shortcutRecorder.shortcut = .defaultShortcut
        statusLabel.stringValue = "保存すると "
            + "\(KeyboardShortcut.defaultShortcut.displayName) が有効になります。"
        window?.makeFirstResponder(shortcutRecorder)
    }

    @objc private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = "履歴に保存しないアプリを選択"
        panel.prompt = "追加"
        panel.message = "選んだアプリでコピーした内容は、MacClipy の履歴に保存されません。"
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
            statusLabel.stringValue = "削除するアプリを一覧から選んでください。"
            return
        }

        let removedName = displayName(for: excludedBundleIdentifiers[selectedRow])
        excludedBundleIdentifiers.remove(at: selectedRow)
        excludedAppsTableView.reloadData()
        statusLabel.stringValue = "保存すると \(removedName) が履歴保存の対象に戻ります。"
    }

    @objc private func resetExcludedApps() {
        excludedBundleIdentifiers = AppSettings.defaultExcludedBundleIdentifiers
        excludedAppsTableView.reloadData()
        statusLabel.stringValue = "保存すると推奨設定に戻ります。"
    }

    func windowWillClose(_ notification: Notification) {
        onDismiss()
    }

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

    private func presentExcludedAppPanel(_ panel: NSOpenPanel) {
        guard panel.runModal() == .OK else {
            return
        }

        appendExcludedApp(from: panel.url)
    }

    private func appendExcludedApp(from appURL: URL?) {
        guard let appURL, let bundle = Bundle(url: appURL), let bundleIdentifier = bundle.bundleIdentifier else {
            statusLabel.stringValue = "アプリ情報を読み取れませんでした。"
                + "別のアプリを選んでください。"
            return
        }

        if excludedBundleIdentifiers.contains(where: { $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame }) {
            statusLabel.stringValue = "\(displayName(for: bundleIdentifier)) はすでに追加されています。"
            return
        }

        excludedBundleIdentifiers.append(bundleIdentifier)
        excludedBundleIdentifiers = AppSettings.normalizedBundleIdentifiers(excludedBundleIdentifiers)
        excludedAppsTableView.reloadData()
        statusLabel.stringValue = "保存すると "
            + "\(displayName(for: bundleIdentifier)) が履歴に保存されなくなります。"
    }

    private func displayName(for bundleIdentifier: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let bundle = Bundle(url: appURL) {
            return appDisplayName(from: bundle, fallbackURL: appURL)
        }

        if bundleIdentifier.caseInsensitiveCompare(Bundle.main.bundleIdentifier ?? "") == .orderedSame {
            return "MacClipy"
        }

        if let knownName = Self.knownAppNames[bundleIdentifier.lowercased()] {
            return knownName
        }

        return bundleIdentifier
    }

    private func appDisplayName(from bundle: Bundle, fallbackURL: URL) -> String {
        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }

        if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !bundleName.isEmpty {
            return bundleName
        }

        return fallbackURL.deletingPathExtension().lastPathComponent
    }

    private static let knownAppNames = [
        "com.1password.1password": "1Password",
        "com.agilebits.onepassword7": "1Password 7",
        "com.bitwarden.desktop": "Bitwarden",
        "org.keepassxc.keepassxc": "KeePassXC",
        "com.apple.keychainaccess": "キーチェーンアクセス",
        "com.local.macclipy": "MacClipy"
    ]
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
