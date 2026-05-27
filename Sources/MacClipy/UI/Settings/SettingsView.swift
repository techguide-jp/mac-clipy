import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    let appModel: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(
                model: appModel.settingsModel,
                onShortcutChange: appModel.refreshStatusMenu
            )
            .tabItem {
                Text(L10n.tr("settings.tab.general"))
            }

            FavoritesManagementView(model: appModel.favoritesModel)
                .tabItem {
                    Text(L10n.tr("settings.tab.favorites"))
                }
        }
        .padding(16)
        .frame(width: 820, height: 580)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var model: SettingsModel
    let onShortcutChange: () -> Void
    @State private var selectedExcludedApp: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            startupAndShortcutSection

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("settings.excludedApps.title"))
                    .font(.headline)
                Text(L10n.tr("settings.excludedApps.help"))
                    .foregroundStyle(.secondary)

                List(selection: $selectedExcludedApp) {
                    ForEach(model.excludedBundleIdentifiers, id: \.self) { bundleIdentifier in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: SettingsDefaults.displayName(for: bundleIdentifier))
                            Text(verbatim: bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 2)
                        .tag(bundleIdentifier)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 240)

                HStack {
                    Button {
                        model.chooseExcludedApp()
                    } label: {
                        Label(L10n.tr("settings.excludedApps.add"), systemImage: "plus")
                    }

                    Button {
                        if let selectedExcludedApp {
                            model.removeExcludedApp(selectedExcludedApp)
                            self.selectedExcludedApp = nil
                        }
                    } label: {
                        Label(L10n.tr("settings.excludedApps.remove"), systemImage: "minus")
                    }
                    .disabled(selectedExcludedApp == nil)

                    Button {
                        model.resetExcludedApps()
                        selectedExcludedApp = nil
                    } label: {
                        Label(L10n.tr("settings.excludedApps.reset"), systemImage: "arrow.counterclockwise")
                    }

                    Spacer()

                    Text(verbatim: model.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var startupAndShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("settings.general.startupAndShortcuts"))
                .font(.headline)

            settingRow(title: L10n.tr("settings.launchAtLogin")) {
                LaunchAtLogin.Toggle {
                    Text(L10n.tr("settings.launchAtLogin"))
                }
                .labelsHidden()
            }

            settingRow(title: L10n.tr("settings.shortcut.title")) {
                KeyboardShortcuts.Recorder(
                    for: .showHistory,
                    onChange: { _ in onShortcutChange() }
                )
            }

            settingRow(title: L10n.tr("settings.favoriteShortcut.title")) {
                KeyboardShortcuts.Recorder(
                    for: .showFavorites,
                    onChange: { _ in onShortcutChange() }
                )
            }
        }
    }

    private func settingRow(title: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 16) {
            Text(verbatim: title)
                .frame(width: 220, alignment: .leading)

            control()

            Spacer()
        }
    }
}
