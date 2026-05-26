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
            Form {
                Section {
                    LaunchAtLogin.Toggle {
                        Text(L10n.tr("settings.launchAtLogin"))
                    }

                    KeyboardShortcuts.Recorder(
                        L10n.tr("settings.shortcut.title"),
                        name: .showHistory,
                        onChange: { _ in onShortcutChange() }
                    )

                    KeyboardShortcuts.Recorder(
                        L10n.tr("settings.favoriteShortcut.title"),
                        name: .showFavorites,
                        onChange: { _ in onShortcutChange() }
                    )
                } header: {
                    Text(L10n.tr("settings.general.startupAndShortcuts"))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("settings.excludedApps.title"))
                    .font(.headline)
                Text(L10n.tr("settings.excludedApps.help"))
                    .foregroundStyle(.secondary)

                List(selection: $selectedExcludedApp) {
                    ForEach(model.excludedBundleIdentifiers, id: \.self) { bundleIdentifier in
                        HStack {
                            Text(verbatim: SettingsDefaults.displayName(for: bundleIdentifier))
                            Spacer()
                            Text(verbatim: bundleIdentifier)
                                .foregroundStyle(.secondary)
                        }
                        .tag(bundleIdentifier)
                    }
                }
                .frame(minHeight: 180)

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
    }
}

private struct FavoritesManagementView: View {
    @Bindable var model: FavoritesModel
    @State private var query = ""
    @State private var assignmentFolderID: UUID?

    var body: some View {
        HStack(spacing: 16) {
            folderColumn
                .frame(width: 240)

            Divider()

            itemColumn
        }
    }

    private var folderColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("settings.favorites.folders"))
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: 4) {
                    folderFilterButton(
                        title: L10n.tr("settings.favorites.folder.all"),
                        filter: .all,
                        systemImage: "tray.full"
                    )
                    folderFilterButton(
                        title: L10n.tr("settings.favorites.folder.unclassified"),
                        filter: .unclassified,
                        systemImage: "tray"
                    )

                    ForEach(model.folders) { folder in
                        folderFilterButton(
                            title: folder.name,
                            filter: .folder(folder.id),
                            systemImage: "folder"
                        )
                    }
                }
            }

            HStack {
                TextField(L10n.tr("settings.favorites.folder.namePrompt"), text: $model.newFolderName)
                Button {
                    model.createFolder()
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel(L10n.tr("settings.favorites.folder.add"))
                }
                .disabled(model.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if case .folder = model.selectedFolderFilter {
                HStack {
                    TextField(L10n.tr("settings.favorites.folder.namePrompt"), text: $model.selectedFolderName)
                    Button {
                        model.renameSelectedFolder(to: model.selectedFolderName)
                    } label: {
                        Image(systemName: "pencil")
                            .accessibilityLabel(L10n.tr("settings.favorites.folder.rename"))
                    }
                }

                HStack {
                    Button {
                        model.moveSelectedFolder(by: -1)
                    } label: {
                        Label(L10n.tr("settings.favorites.folder.up"), systemImage: "arrow.up")
                    }

                    Button {
                        model.moveSelectedFolder(by: 1)
                    } label: {
                        Label(L10n.tr("settings.favorites.folder.down"), systemImage: "arrow.down")
                    }

                    Button(role: .destructive) {
                        model.deleteSelectedFolder()
                    } label: {
                        Label(L10n.tr("settings.favorites.folder.delete"), systemImage: "trash")
                    }
                }
            }
        }
    }

    private var itemColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("settings.favorites.items"))
                    .font(.headline)

                Spacer()

                Picker(selection: $model.selectedSort) {
                    Text(L10n.tr("settings.favorites.sort.manual")).tag(FavoriteItemSort.manual)
                    Text(L10n.tr("settings.favorites.sort.title")).tag(FavoriteItemSort.title)
                    Text(L10n.tr("settings.favorites.sort.lastUsed")).tag(FavoriteItemSort.lastUsed)
                    Text(L10n.tr("settings.favorites.sort.useCount")).tag(FavoriteItemSort.useCount)
                } label: {
                    Text(L10n.tr("settings.favorites.sort.titleLabel"))
                }
                .frame(width: 190)
            }

            TextField(L10n.tr("historyPopup.searchPlaceholder"), text: $query)

            ScrollView {
                LazyVStack(spacing: 4) {
                    let visibleItems = model.visibleItems(query: query)
                    if visibleItems.isEmpty {
                        Text(L10n.tr("settings.favorites.empty"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(visibleItems) { favorite in
                            favoriteRow(favorite)
                        }
                    }
                }
            }

            selectedFavoriteEditor
            Text(verbatim: model.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var selectedFavoriteEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(L10n.tr("settings.favorites.item.titlePrompt"), text: $model.draftFavoriteTitle)
                .disabled(model.selectedFavoriteID == nil)

            HStack {
                Button {
                    model.updateSelectedFavoriteTitle()
                } label: {
                    Label(L10n.tr("settings.favorites.item.rename"), systemImage: "pencil")
                }
                .disabled(model.selectedFavoriteID == nil)

                Picker(selection: $assignmentFolderID) {
                    Text(L10n.tr("settings.favorites.folder.none")).tag(UUID?.none)
                    ForEach(model.folders) { folder in
                        Text(verbatim: folder.name).tag(Optional(folder.id))
                    }
                } label: {
                    Text(L10n.tr("settings.favorites.assignFolder"))
                }
                .frame(width: 220)

                Button {
                    if let assignmentFolderID {
                        model.addSelectedFavorite(to: assignmentFolderID)
                    }
                } label: {
                    Label(L10n.tr("settings.favorites.item.addToFolder"), systemImage: "folder.badge.plus")
                }
                .disabled(model.selectedFavoriteID == nil || assignmentFolderID == nil)

                if let selectedFavoriteID = model.selectedFavoriteID,
                   case let .folder(folderID) = model.selectedFolderFilter,
                   model.folderIDs(for: selectedFavoriteID).contains(folderID)
                {
                    Button {
                        model.removeSelectedFavorite(from: folderID)
                    } label: {
                        Label(L10n.tr("settings.favorites.item.removeFromFolder"), systemImage: "folder.badge.minus")
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    model.removeSelectedFavorite()
                } label: {
                    Label(L10n.tr("settings.favorites.item.remove"), systemImage: "star.slash")
                }
                .disabled(model.selectedFavoriteID == nil)
            }
        }
    }

    private func folderFilterButton(title: String, filter: FavoriteFolderFilter, systemImage: String) -> some View {
        Button {
            model.selectFolderFilter(filter)
        } label: {
            HStack {
                Image(systemName: systemImage)
                Text(verbatim: title)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(model.selectedFolderFilter == filter ? Color.accentColor.opacity(0.16) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func favoriteRow(_ favorite: FavoriteItem) -> some View {
        Button {
            model.selectFavorite(favorite)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: favorite.menuTitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(verbatim: favoriteDetail(for: favorite))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(model.selectedFavoriteID == favorite.id ? Color.accentColor.opacity(0.16) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func favoriteDetail(for favorite: FavoriteItem) -> String {
        let folderNames = model.folderNames(for: favorite.id)
        let folderSummary = folderNames.isEmpty
            ? L10n.tr("settings.favorites.folder.unclassified")
            : folderNames.joined(separator: ", ")
        return L10n.tr("settings.favorites.item.detailWithFolders", favorite.useCount, folderSummary)
    }
}
