import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let onSave: () -> Void
    private let textView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")

    init(settingsStore: SettingsStore, onSave: @escaping () -> Void) {
        self.settingsStore = settingsStore
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacClipy 設定"
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        textView.string = settingsStore.settings.excludedBundleIdentifiers.joined(separator: "\n")
        statusLabel.stringValue = ""

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(textView)
        }
    }

    private func buildInterface() {
        guard let window else {
            return
        }

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let titleLabel = NSTextField(labelWithString: "除外する bundle id")
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: "キャンセル", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(scrollView)
        contentView.addSubview(statusLabel)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -10),

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
        let identifiers = textView.string.components(separatedBy: .newlines)

        do {
            try settingsStore.updateExcludedBundleIdentifiers(identifiers)
            statusLabel.stringValue = "保存しました"
            onSave()
            window?.orderOut(nil)
        } catch {
            statusLabel.stringValue = "保存に失敗しました: \(error.localizedDescription)"
        }
    }

    @objc private func cancel() {
        window?.orderOut(nil)
    }
}
