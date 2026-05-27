import SwiftUI

struct FavoritesManagementView: View {
    private enum FolderFieldFocus: Hashable {
        case newFolder
        case existingFolder(UUID)
    }

    @Bindable var model: FavoritesModel
    @State private var query = ""
    @State private var assignmentFolderID: UUID?
    @State private var isCreatingFolder = false
    @State private var newFolderDraft = ""
    @State private var editingFolderID: UUID?
    @State private var editingFolderName = ""
    @FocusState private var focusedFolderField: FolderFieldFocus?

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
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("settings.favorites.item.favoriteName"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(L10n.tr("settings.favorites.item.titlePrompt"), text: $model.draftFavoriteTitle)
                    .disabled(model.selectedFavoriteID == nil)
            }

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
                   model.folderIDs(for: selectedFavoriteID).contains(folderID) {
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

    private var selectedFavorite: FavoriteItem? {
        guard let selectedFavoriteID = model.selectedFavoriteID else {
            return nil
        }

        return model.items.first { $0.id == selectedFavoriteID }
    }

    private var newFolderRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .foregroundStyle(.secondary)

            TextField(L10n.tr("settings.favorites.folder.namePrompt"), text: $newFolderDraft)
                .focused($focusedFolderField, equals: .newFolder)
                .onSubmit {
                    commitNewFolder()
                }

            Button {
                commitNewFolder()
            } label: {
                Image(systemName: "checkmark")
                    .accessibilityLabel(L10n.tr("button.save"))
            }
            .buttonStyle(.plain)
            .disabled(newFolderDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                cancelFolderEditing()
            } label: {
                Image(systemName: "xmark")
                    .accessibilityLabel(L10n.tr("button.cancel"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .background(Color.accentColor.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            focusFolderField(.newFolder)
        }
    }

    private func editingFolderRow(_ folder: FavoriteFolder) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            TextField(L10n.tr("settings.favorites.folder.namePrompt"), text: $editingFolderName)
                .focused($focusedFolderField, equals: .existingFolder(folder.id))
                .onSubmit {
                    commitFolderRename(folder.id)
                }

            Button {
                commitFolderRename(folder.id)
            } label: {
                Image(systemName: "checkmark")
                    .accessibilityLabel(L10n.tr("button.save"))
            }
            .buttonStyle(.plain)
            .disabled(editingFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                cancelFolderEditing()
            } label: {
                Image(systemName: "xmark")
                    .accessibilityLabel(L10n.tr("button.cancel"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .background(Color.accentColor.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            focusFolderField(.existingFolder(folder.id))
        }
    }

    private func folderFilterButton(
        title: String,
        filter: FavoriteFolderFilter,
        systemImage: String,
        editableFolder: FavoriteFolder? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)

            Text(verbatim: title)
                .lineLimit(1)

            Spacer()

            if let editableFolder {
                Button {
                    beginRenamingFolder(editableFolder)
                } label: {
                    Image(systemName: "pencil")
                        .accessibilityLabel(L10n.tr("settings.favorites.folder.rename"))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("settings.favorites.folder.rename"))
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .background(model.selectedFolderFilter == filter ? Color.accentColor.opacity(0.16) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectFolderFilter(filter)
        }
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
                    if favorite.hasCustomDisplayTitle {
                        Text(verbatim: favorite.contentMenuTitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(model.selectedFavoriteID == favorite.id ? Color.accentColor.opacity(0.16) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func beginCreatingFolder() {
        cancelFolderEditing()
        isCreatingFolder = true
        newFolderDraft = ""
        focusedFolderField = .newFolder
        focusFolderField(.newFolder)
    }

    private func beginRenamingFolder(_ folder: FavoriteFolder) {
        isCreatingFolder = false
        newFolderDraft = ""
        model.selectFolderFilter(.folder(folder.id))
        editingFolderID = folder.id
        editingFolderName = folder.name
        focusedFolderField = .existingFolder(folder.id)
        focusFolderField(.existingFolder(folder.id))
    }

    private func focusFolderField(_ field: FolderFieldFocus) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            if case .newFolder = field, !isCreatingFolder { return }
            if case let .existingFolder(folderID) = field, editingFolderID != folderID { return }
            focusedFolderField = field
        }
    }

    private func commitNewFolder() {
        let trimmedName = newFolderDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        model.newFolderName = trimmedName
        model.createFolder()
        isCreatingFolder = false
        newFolderDraft = ""
        focusedFolderField = nil
    }

    private func commitFolderRename(_ folderID: UUID) {
        let trimmedName = editingFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        model.selectFolderFilter(.folder(folderID))
        model.renameSelectedFolder(to: trimmedName)
        editingFolderID = nil
        editingFolderName = ""
        focusedFolderField = nil
    }

    private func cancelFolderEditing() {
        isCreatingFolder = false
        newFolderDraft = ""
        editingFolderID = nil
        editingFolderName = ""
        focusedFolderField = nil
    }
}
