import SwiftUI

struct FavoritesManagementView: View {
    enum FolderFieldFocus: Hashable {
        case newFolder
        case existingFolder(UUID)
        case favorite(UUID)
    }

    @Bindable var model: FavoritesModel
    @State var query = ""
    @State var assignmentFolderID: UUID?
    @State var isCreatingFolder = false
    @State var newFolderDraft = ""
    @State var editingFolderID: UUID?
    @State var editingFolderName = ""
    @State var editingFavoriteID: UUID?
    @State var editingFavoriteTitle = ""
    @FocusState var focusedFolderField: FolderFieldFocus?

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
            HStack {
                Text(L10n.tr("settings.favorites.folders"))
                    .font(.headline)

                Spacer()

                Button {
                    beginCreatingFolder()
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel(L10n.tr("settings.favorites.folder.add"))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("settings.favorites.folder.add"))
            }

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

                    if isCreatingFolder {
                        newFolderRow
                    }

                    ForEach(model.folders) { folder in
                        if editingFolderID == folder.id {
                            editingFolderRow(folder)
                        } else {
                            folderFilterButton(
                                title: folder.name,
                                filter: .folder(folder.id),
                                systemImage: "folder",
                                editableFolder: folder
                            )
                        }
                    }
                }
            }

            if case .folder = model.selectedFolderFilter {
                HStack(spacing: 8) {
                    Button {
                        model.moveSelectedFolder(by: -1)
                    } label: {
                        Image(systemName: "arrow.up")
                            .accessibilityLabel(L10n.tr("settings.favorites.folder.up"))
                    }
                    .help(L10n.tr("settings.favorites.folder.up"))

                    Button {
                        model.moveSelectedFolder(by: 1)
                    } label: {
                        Image(systemName: "arrow.down")
                            .accessibilityLabel(L10n.tr("settings.favorites.folder.down"))
                    }
                    .help(L10n.tr("settings.favorites.folder.down"))

                    Button(role: .destructive) {
                        model.deleteSelectedFolder()
                    } label: {
                        Image(systemName: "trash")
                            .accessibilityLabel(L10n.tr("settings.favorites.folder.delete"))
                    }
                    .help(L10n.tr("settings.favorites.folder.delete"))

                    Spacer()
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
                            if editingFavoriteID == favorite.id {
                                editingFavoriteRow(favorite)
                            } else {
                                favoriteRow(favorite)
                            }
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
            if let selectedFavorite {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("settings.favorites.item.copyValue"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: selectedFavorite.contentMenuTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack(spacing: 8) {
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
                    Image(systemName: "folder.badge.plus")
                        .accessibilityLabel(L10n.tr("settings.favorites.item.addToFolder"))
                }
                .disabled(model.selectedFavoriteID == nil || assignmentFolderID == nil)
                .help(L10n.tr("settings.favorites.item.addToFolder"))

                if let selectedFavoriteID = model.selectedFavoriteID,
                   case let .folder(folderID) = model.selectedFolderFilter,
                   model.folderIDs(for: selectedFavoriteID).contains(folderID) {
                    Button {
                        model.removeSelectedFavorite(from: folderID)
                    } label: {
                        Image(systemName: "folder.badge.minus")
                            .accessibilityLabel(L10n.tr("settings.favorites.item.removeFromFolder"))
                    }
                    .help(L10n.tr("settings.favorites.item.removeFromFolder"))
                }

                Spacer()

                Button(role: .destructive) {
                    model.removeSelectedFavorite()
                } label: {
                    Image(systemName: "star.slash")
                        .accessibilityLabel(L10n.tr("settings.favorites.item.remove"))
                }
                .disabled(model.selectedFavoriteID == nil)
                .help(L10n.tr("settings.favorites.item.remove"))
            }
        }
    }

    private var selectedFavorite: FavoriteItem? {
        guard let selectedFavoriteID = model.selectedFavoriteID else {
            return nil
        }

        return model.items.first { $0.id == selectedFavoriteID }
    }
}
