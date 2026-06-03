import KeyboardShortcuts

enum KeyboardShortcutDisplay {
    static func displayName(for name: KeyboardShortcuts.Name) -> String {
        KeyboardShortcuts.getShortcut(for: name).map { "\($0)" } ?? L10n.tr("settings.shortcut.notSet")
    }
}
