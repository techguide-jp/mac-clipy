import SwiftUI

struct KeyboardHelpView: View {
    private struct HelpRow: Identifiable {
        let id = UUID()
        let keys: String
        let actionKey: String
    }

    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.tr("keyboardHelp.title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .accessibilityLabel(L10n.tr("button.close"))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("button.close"))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    helpSection(
                        title: L10n.tr("keyboardHelp.section.global"),
                        rows: globalRows
                    )
                    helpSection(
                        title: L10n.tr("keyboardHelp.section.popup"),
                        rows: popupRows
                    )
                    helpSection(
                        title: L10n.tr("keyboardHelp.section.settings"),
                        rows: settingsRows
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()

                Button(L10n.tr("button.ok")) {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 640, height: 560)
    }

    private var globalRows: [HelpRow] {
        [
            HelpRow(
                keys: KeyboardShortcutDisplay.displayName(for: .showHistory),
                actionKey: "keyboardHelp.global.history"
            ),
            HelpRow(
                keys: KeyboardShortcutDisplay.displayName(for: .showFavorites),
                actionKey: "keyboardHelp.global.favorites"
            ),
            HelpRow(
                keys: KeyboardShortcutDisplay.displayName(for: .showHelp),
                actionKey: "keyboardHelp.global.help"
            ),
            HelpRow(keys: "Command + ,", actionKey: "keyboardHelp.global.settings")
        ]
    }

    private var popupRows: [HelpRow] {
        [
            HelpRow(keys: L10n.tr("keyboardHelp.key.type"), actionKey: "keyboardHelp.popup.search"),
            HelpRow(keys: "Up / Down", actionKey: "keyboardHelp.popup.moveSelection"),
            HelpRow(keys: "Return", actionKey: "keyboardHelp.popup.choose"),
            HelpRow(keys: "Esc", actionKey: "keyboardHelp.popup.close"),
            HelpRow(keys: "Left / Right", actionKey: "keyboardHelp.popup.switchScope"),
            HelpRow(keys: "Command + D", actionKey: "keyboardHelp.popup.toggleFavorite"),
            HelpRow(keys: "Command + Shift + F", actionKey: "keyboardHelp.popup.toggleMode"),
            HelpRow(keys: "Command + 1...9", actionKey: "keyboardHelp.popup.folderShortcut"),
            HelpRow(keys: "? / Command + ?", actionKey: "keyboardHelp.openHelp")
        ]
    }

    private var settingsRows: [HelpRow] {
        [
            HelpRow(keys: "Command + 1 / 2 / 3", actionKey: "keyboardHelp.settings.switchTabs"),
            HelpRow(keys: "Command + F", actionKey: "keyboardHelp.settings.focusSearch"),
            HelpRow(keys: "Tab / Shift + Tab", actionKey: "keyboardHelp.settings.moveFocus"),
            HelpRow(keys: "Up / Down", actionKey: "keyboardHelp.settings.moveSelection"),
            HelpRow(keys: "Return / F2", actionKey: "keyboardHelp.settings.renameSelected"),
            HelpRow(keys: "Command + N", actionKey: "keyboardHelp.settings.newFolder"),
            HelpRow(keys: "Command + Up / Down", actionKey: "keyboardHelp.settings.moveFolder"),
            HelpRow(keys: "Delete", actionKey: "keyboardHelp.settings.deleteSelected"),
            HelpRow(keys: "Esc", actionKey: "keyboardHelp.settings.cancel"),
            HelpRow(keys: "? / Command + ?", actionKey: "keyboardHelp.openHelp")
        ]
    }

    private func helpSection(title: String, rows: [HelpRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(.headline)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 6) {
                ForEach(rows) { row in
                    GridRow {
                        Text(verbatim: row.keys)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 180, alignment: .leading)

                        Text(L10n.tr(row.actionKey))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
