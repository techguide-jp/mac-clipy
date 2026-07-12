import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    @Bindable var appModel: AppModel
    @State private var selectedTab: SettingsTab = .general
    @State private var favoriteSearchFocusRevision = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()

                Button {
                    appModel.showKeyboardHelp()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .accessibilityLabel(L10n.tr("button.keyboardHelp"))
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("button.keyboardHelp"))
            }

            TabView(selection: $selectedTab) {
                GeneralSettingsView(
                    model: appModel.settingsModel,
                    updater: appModel.appUpdater,
                    onShortcutChange: appModel.refreshStatusMenu
                )
                .tabItem {
                    Text(L10n.tr("settings.tab.general"))
                }
                .tag(SettingsTab.general)

                FavoritesManagementView(
                    model: appModel.favoritesModel,
                    searchFocusRevision: favoriteSearchFocusRevision
                )
                .tabItem {
                    Text(L10n.tr("settings.tab.favorites"))
                }
                .tag(SettingsTab.favorites)
            }
        }
        .padding(16)
        .frame(width: 820, height: 580)
        .sheet(isPresented: $appModel.isKeyboardHelpPresented) {
            KeyboardHelpView {
                appModel.isKeyboardHelpPresented = false
            }
        }
        .sheet(item: $appModel.developmentCrashReport) { report in
            DevelopmentCrashReportView(report: report) {
                appModel.developmentCrashReport = nil
            }
        }
        .background(
            KeyboardEventBridge { event, isTextEditing in
                SettingsKeyAction.handle(
                    event: event,
                    isTextEditing: isTextEditing,
                    selectTab: { selectedTab = $0 },
                    focusFavoritesSearch: {
                        favoriteSearchFocusRevision += 1
                    },
                    showHelp: appModel.showKeyboardHelp
                )
            }
        )
    }
}

private struct GeneralSettingsView: View {
    @Bindable var model: SettingsModel
    @Bindable var updater: AppUpdater
    let onShortcutChange: () -> Void
    @State private var selectedExcludedApp: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            startupAndShortcutSection

            Divider()

            updatesSection

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

            settingRow(title: L10n.tr("settings.helpShortcut.title")) {
                KeyboardShortcuts.Recorder(
                    for: .showHelp,
                    onChange: { _ in onShortcutChange() }
                )
            }
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("settings.updates.title"))
                .font(.headline)

            settingRow(title: L10n.tr("settings.updates.automaticChecks")) {
                Toggle(
                    L10n.tr("settings.updates.automaticChecks"),
                    isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    )
                )
                .labelsHidden()
            }

            settingRow(title: L10n.tr("settings.updates.automaticDownloads")) {
                Toggle(
                    L10n.tr("settings.updates.automaticDownloads"),
                    isOn: Binding(
                        get: { updater.automaticallyDownloadsUpdates },
                        set: { updater.automaticallyDownloadsUpdates = $0 }
                    )
                )
                .labelsHidden()
                .disabled(!updater.allowsAutomaticUpdates)
            }

            Button {
                updater.checkForUpdates()
            } label: {
                Label(L10n.tr("settings.updates.checkNow"), systemImage: "arrow.down.circle")
            }
            .disabled(!updater.canCheckForUpdates)
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
