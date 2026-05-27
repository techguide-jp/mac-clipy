import SwiftUI

extension FavoritesManagementView {
    var newFolderRow: some View {
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

    func editingFolderRow(_ folder: FavoriteFolder) -> some View {
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

    func folderFilterButton(
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
        .overlay(focusRing(isFocused: keyboardFocus == .folders && model.selectedFolderFilter == filter))
        .contentShape(Rectangle())
        .onTapGesture {
            selectFolderFilterFromKeyboard(filter)
        }
        .contextMenu {
            if let editableFolder {
                Button {
                    beginRenamingFolder(editableFolder)
                } label: {
                    Label(L10n.tr("settings.favorites.folder.rename"), systemImage: "pencil")
                }

                Button {
                    moveFolder(editableFolder, by: -1)
                } label: {
                    Label(L10n.tr("settings.favorites.folder.up"), systemImage: "arrow.up")
                }

                Button {
                    moveFolder(editableFolder, by: 1)
                } label: {
                    Label(L10n.tr("settings.favorites.folder.down"), systemImage: "arrow.down")
                }

                Divider()

                Button(role: .destructive) {
                    requestDeleteFolder(editableFolder)
                } label: {
                    Label(L10n.tr("settings.favorites.folder.delete"), systemImage: "trash")
                }
            }
        }
    }

    func favoriteRow(_ favorite: FavoriteItem) -> some View {
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

            Button {
                beginRenamingFavorite(favorite)
            } label: {
                Image(systemName: "pencil")
                    .accessibilityLabel(L10n.tr("settings.favorites.item.rename"))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("settings.favorites.item.rename"))
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(model.selectedFavoriteID == favorite.id ? Color.accentColor.opacity(0.16) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(focusRing(isFocused: keyboardFocus == .items && model.selectedFavoriteID == favorite.id))
        .contentShape(Rectangle())
        .onTapGesture {
            selectFavoriteFromKeyboard(favorite)
        }
        .contextMenu {
            favoriteContextMenu(for: favorite)
        }
    }

    func editingFavoriteRow(_ favorite: FavoriteItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)

            TextField(L10n.tr("settings.favorites.item.titlePrompt"), text: $editingFavoriteTitle)
                .focused($focusedFolderField, equals: .favorite(favorite.id))
                .onSubmit {
                    commitFavoriteRename(favorite.id)
                }

            Button {
                commitFavoriteRename(favorite.id)
            } label: {
                Image(systemName: "checkmark")
                    .accessibilityLabel(L10n.tr("button.save"))
            }
            .buttonStyle(.plain)

            Button {
                cancelFavoriteEditing()
            } label: {
                Image(systemName: "xmark")
                    .accessibilityLabel(L10n.tr("button.cancel"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(Color.accentColor.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            focusFolderField(.favorite(favorite.id))
        }
    }

    @ViewBuilder
    func favoriteContextMenu(for favorite: FavoriteItem) -> some View {
        Button {
            beginRenamingFavorite(favorite)
        } label: {
            Label(L10n.tr("settings.favorites.item.rename"), systemImage: "pencil")
        }

        if !model.folders.isEmpty {
            Menu {
                ForEach(model.folders) { folder in
                    Button {
                        addFavorite(favorite, to: folder)
                    } label: {
                        Text(verbatim: folder.name)
                    }
                }
            } label: {
                Label(L10n.tr("settings.favorites.assignFolder"), systemImage: "folder.badge.plus")
            }
        }

        if case let .folder(folderID) = model.selectedFolderFilter,
           model.folderIDs(for: favorite.id).contains(folderID) {
            Button {
                removeFavorite(favorite, from: folderID)
            } label: {
                Label(L10n.tr("settings.favorites.item.removeFromFolder"), systemImage: "folder.badge.minus")
            }
        }

        Divider()

        Button(role: .destructive) {
            requestRemoveFavorite(favorite)
        } label: {
            Label(L10n.tr("settings.favorites.item.remove"), systemImage: "star.slash")
        }
    }

    func focusRing(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1)
    }
}
