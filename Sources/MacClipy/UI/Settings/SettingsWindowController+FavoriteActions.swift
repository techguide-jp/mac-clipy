import AppKit

extension SettingsWindowController {
    @objc func addFavoriteFolder() {
        guard let name = promptForText(
            title: L10n.tr("settings.favorites.folder.add"),
            message: L10n.tr("settings.favorites.folder.namePrompt"),
            defaultValue: ""
        ) else {
            return
        }

        do {
            try favoriteStore.createFolder(named: name)
            reloadFavoriteManagement()
            statusLabel.stringValue = L10n.tr("settings.favorites.status.folderAdded")
        } catch {
            statusLabel.stringValue = L10n.tr("settings.status.saveFailed", error.localizedDescription)
        }
    }

    @objc func renameFavoriteFolder() {
        guard let folder = selectedConcreteFolder() else {
            statusLabel.stringValue = L10n.tr("settings.favorites.status.selectFolder")
            return
        }
        guard let name = promptForText(
            title: L10n.tr("settings.favorites.folder.rename"),
            message: L10n.tr("settings.favorites.folder.namePrompt"),
            defaultValue: folder.name
        ) else {
            return
        }

        do {
            try favoriteStore.renameFolder(id: folder.id, name: name)
            reloadFavoriteManagement()
            statusLabel.stringValue = L10n.tr("settings.favorites.status.folderRenamed")
        } catch {
            statusLabel.stringValue = L10n.tr("settings.status.saveFailed", error.localizedDescription)
        }
    }

    @objc func deleteFavoriteFolder() {
        guard let folder = selectedConcreteFolder() else {
            statusLabel.stringValue = L10n.tr("settings.favorites.status.selectFolder")
            return
        }
        guard confirm(
            title: L10n.tr("settings.favorites.folder.delete"),
            message: L10n.tr("settings.favorites.folder.deleteMessage")
        ) else {
            return
        }

        do {
            try favoriteStore.deleteFolder(id: folder.id)
            favoriteFoldersTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            reloadFavoriteManagement()
            statusLabel.stringValue = L10n.tr("settings.favorites.status.folderDeleted")
        } catch {
            statusLabel.stringValue = L10n.tr("settings.status.saveFailed", error.localizedDescription)
        }
    }

    @objc func moveFavoriteFolderUp() {
        moveSelectedFavoriteFolder(by: -1)
    }

    @objc func moveFavoriteFolderDown() {
        moveSelectedFavoriteFolder(by: 1)
    }

    @objc func renameFavoriteItem() {
        guard let favorite = selectedFavoriteItem() else {
            statusLabel.stringValue = L10n.tr("settings.favorites.status.selectFavorite")
            return
        }
        guard let title = promptForText(
            title: L10n.tr("settings.favorites.item.rename"),
            message: L10n.tr("settings.favorites.item.titlePrompt"),
            defaultValue: favorite.displayTitle
        ) else {
            return
        }

        do {
            try favoriteStore.updateDisplayTitle(id: favorite.id, title: title)
            reloadFavoriteManagement()
            statusLabel.stringValue = L10n.tr("settings.favorites.status.favoriteRenamed")
        } catch {
            statusLabel.stringValue = L10n.tr("settings.status.saveFailed", error.localizedDescription)
        }
    }

    @objc func removeFavoriteItem() {
        guard let favorite = selectedFavoriteItem() else {
            statusLabel.stringValue = L10n.tr("settings.favorites.status.selectFavorite")
            return
        }

        do {
            try favoriteStore.removeFavorite(id: favorite.id)
            reloadFavoriteManagement()
            statusLabel.stringValue = L10n.tr("settings.favorites.status.favoriteRemoved")
        } catch {
            statusLabel.stringValue = L10n.tr("settings.status.saveFailed", error.localizedDescription)
        }
    }

    @objc func addFavoriteItemToFolder() {
        guard let favorite = selectedFavoriteItem() else {
            statusLabel.stringValue = L10n.tr("settings.favorites.status.selectFavorite")
            return
        }
        guard let folderID = folderAssignmentPopup.selectedItem?.representedObject as? UUID else {
            statusLabel.stringValue = L10n.tr("settings.favorites.status.selectFolder")
            return
        }

        do {
            try favoriteStore.addFavorite(id: favorite.id, to: folderID)
            reloadFavoriteManagement()
            statusLabel.stringValue = L10n.tr("settings.favorites.status.favoriteAssigned")
        } catch {
            statusLabel.stringValue = L10n.tr("settings.status.saveFailed", error.localizedDescription)
        }
    }

    @objc func removeFavoriteItemFromFolder() {
        guard let favorite = selectedFavoriteItem() else {
            statusLabel.stringValue = L10n.tr("settings.favorites.status.selectFavorite")
            return
        }
        guard case .folder(let folderID) = selectedFavoriteFolderFilter() else {
            statusLabel.stringValue = L10n.tr("settings.favorites.status.selectConcreteFolder")
            return
        }

        do {
            try favoriteStore.removeFavorite(id: favorite.id, from: folderID)
            reloadFavoriteManagement()
            statusLabel.stringValue = L10n.tr("settings.favorites.status.favoriteUnassigned")
        } catch {
            statusLabel.stringValue = L10n.tr("settings.status.saveFailed", error.localizedDescription)
        }
    }
}
