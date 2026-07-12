import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    @Bindable var appModel: AppModel
    @State private var selectedTab: SettingsTab = .general
    @State private var favoriteSearchFocusRevision = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                updater: appModel.appUpdater,
                onShortcutChange: appModel.refreshStatusMenu,
                onShowOnboarding: appModel.showOnboarding,
                onShowKeyboardHelp: appModel.showKeyboardHelp
            )
            .tabItem {
                Label(L10n.tr("settings.tab.general"), systemImage: "gearshape")
            }
            .tag(SettingsTab.general)

            FavoritesManagementView(
                model: appModel.favoritesModel,
                searchFocusRevision: favoriteSearchFocusRevision
            )
            .tabItem {
                Label(L10n.tr("settings.tab.favorites"), systemImage: "star")
            }
            .tag(SettingsTab.favorites)

            ExcludedAppsSettingsView(model: appModel.settingsModel)
                .tabItem {
                    Label(L10n.tr("settings.tab.excludedApps"), systemImage: "eye.slash")
                }
                .tag(SettingsTab.excludedApps)
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
    @Bindable var updater: AppUpdater
    let onShortcutChange: () -> Void
    let onShowOnboarding: () -> Void
    let onShowKeyboardHelp: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsSection(
                    title: L10n.tr("settings.general.startup.title"),
                    description: L10n.tr("settings.general.startup.help"),
                    systemImage: "power"
                ) {
                    settingRow(title: L10n.tr("settings.launchAtLogin")) {
                        LaunchAtLogin.Toggle {
                            Text(L10n.tr("settings.launchAtLogin"))
                        }
                        .labelsHidden()
                    }
                }

                SettingsSection(
                    title: L10n.tr("settings.general.shortcuts.title"),
                    description: L10n.tr("settings.general.shortcuts.help"),
                    systemImage: "keyboard"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
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

                SettingsSection(
                    title: L10n.tr("settings.updates.title"),
                    description: L10n.tr("settings.updates.help"),
                    systemImage: "arrow.triangle.2.circlepath"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
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

                SettingsSection(
                    title: L10n.tr("settings.general.guide.title"),
                    description: L10n.tr("settings.general.guide.help"),
                    systemImage: "book.closed"
                ) {
                    HStack(spacing: 10) {
                        Button(action: onShowOnboarding) {
                            Label(L10n.tr("settings.general.guide.show"), systemImage: "play.rectangle")
                        }

                        Button(action: onShowKeyboardHelp) {
                            Label(L10n.tr("settings.general.guide.keyboardHelp"), systemImage: "keyboard")
                        }

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.never)
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

private struct SettingsSection<Content: View>: View {
    let title: String
    let description: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: title)
                        .font(.headline)
                    Text(verbatim: description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            content()
                .padding(.leading, 42)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
    }
}
