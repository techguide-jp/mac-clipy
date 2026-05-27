import Foundation

extension FavoritesManagementView {
    func beginCreatingFolder() {
        cancelFolderEditing()
        cancelFavoriteEditing()
        isCreatingFolder = true
        newFolderDraft = ""
        focusedFolderField = .newFolder
        focusFolderField(.newFolder)
    }

    func beginRenamingFolder(_ folder: FavoriteFolder) {
        isCreatingFolder = false
        cancelFavoriteEditing()
        newFolderDraft = ""
        model.selectFolderFilter(.folder(folder.id))
        editingFolderID = folder.id
        editingFolderName = folder.name
        focusedFolderField = .existingFolder(folder.id)
        focusFolderField(.existingFolder(folder.id))
    }

    func focusFolderField(_ field: FolderFieldFocus) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            if case .newFolder = field, !isCreatingFolder { return }
            if case let .existingFolder(folderID) = field, editingFolderID != folderID { return }
            if case let .favorite(favoriteID) = field, editingFavoriteID != favoriteID { return }
            focusedFolderField = field
        }
    }

    func commitNewFolder() {
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

    func commitFolderRename(_ folderID: UUID) {
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

    func cancelFolderEditing() {
        isCreatingFolder = false
        newFolderDraft = ""
        editingFolderID = nil
        editingFolderName = ""
        focusedFolderField = nil
    }

    func moveFolder(_ folder: FavoriteFolder, by offset: Int) {
        model.selectFolderFilter(.folder(folder.id))
        model.moveSelectedFolder(by: offset)
    }

    func requestDeleteSelectedFolder() {
        guard case let .folder(folderID) = model.selectedFolderFilter else {
            return
        }

        deletionConfirmation = .folder(folderID)
    }

    func requestDeleteFolder(_ folder: FavoriteFolder) {
        model.selectFolderFilter(.folder(folder.id))
        deletionConfirmation = .folder(folder.id)
    }

    func deleteFolder(_ folder: FavoriteFolder) {
        model.selectFolderFilter(.folder(folder.id))
        model.deleteSelectedFolder()
        cancelFolderEditing()
    }

    func beginRenamingFavorite(_ favorite: FavoriteItem) {
        cancelFolderEditing()
        model.selectFavorite(favorite)
        editingFavoriteID = favorite.id
        editingFavoriteTitle = favorite.menuTitle
        focusedFolderField = .favorite(favorite.id)
        focusFolderField(.favorite(favorite.id))
    }

    func commitFavoriteRename(_ favoriteID: UUID) {
        model.selectFavorite(model.items.first { $0.id == favoriteID })
        model.draftFavoriteTitle = editingFavoriteTitle
        model.updateSelectedFavoriteTitle()
        cancelFavoriteEditing()
    }

    func addFavorite(_ favorite: FavoriteItem, to folder: FavoriteFolder) {
        model.selectFavorite(favorite)
        model.addSelectedFavorite(to: folder.id)
    }

    func removeFavorite(_ favorite: FavoriteItem, from folderID: UUID) {
        model.selectFavorite(favorite)
        model.removeSelectedFavorite(from: folderID)
    }

    func requestRemoveSelectedFavorite() {
        guard let selectedFavoriteID = model.selectedFavoriteID else {
            return
        }

        deletionConfirmation = .favorite(selectedFavoriteID)
    }

    func requestRemoveFavorite(_ favorite: FavoriteItem) {
        model.selectFavorite(favorite)
        deletionConfirmation = .favorite(favorite.id)
    }

    func removeFavorite(_ favorite: FavoriteItem) {
        model.selectFavorite(favorite)
        model.removeSelectedFavorite()
        cancelFavoriteEditing()
    }

    func confirmDeletion() {
        guard let deletionConfirmation else {
            return
        }

        switch deletionConfirmation {
        case let .folder(folderID):
            if let folder = model.folders.first(where: { $0.id == folderID }) {
                deleteFolder(folder)
            }
        case let .favorite(favoriteID):
            if let favorite = model.items.first(where: { $0.id == favoriteID }) {
                removeFavorite(favorite)
            }
        }

        self.deletionConfirmation = nil
    }

    func cancelFavoriteEditing() {
        editingFavoriteID = nil
        editingFavoriteTitle = ""
        focusedFolderField = nil
    }
}
