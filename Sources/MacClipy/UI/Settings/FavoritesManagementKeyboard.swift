import AppKit
import Carbon

extension FavoritesManagementView {
    func handleKeyboard(event: NSEvent, isTextEditing: Bool) -> Bool {
        if isTextEditing {
            return handleTextEditingKeyboard(event: event)
        }

        if handleFavoritesCommand(event: event) {
            return true
        }

        switch event.keyCode {
        case UInt16(kVK_Escape):
            return cancelActiveFavoritesInput()
        case UInt16(kVK_Return), UInt16(kVK_F2):
            return beginRenamingSelectedEntry()
        case UInt16(kVK_Delete), UInt16(kVK_ForwardDelete):
            return requestDeletingSelectedEntry()
        default:
            return false
        }
    }

    private func handleTextEditingKeyboard(event: NSEvent) -> Bool {
        guard event.keyCode == UInt16(kVK_Escape) else {
            return false
        }

        return cancelActiveFavoritesInput()
    }

    private func handleFavoritesCommand(event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control)
        else {
            return false
        }

        if !modifiers.contains(.shift),
           event.charactersIgnoringModifiers?.lowercased() == "n" {
            beginCreatingFolder()
            return true
        }

        guard !modifiers.contains(.shift) else {
            return false
        }

        switch event.keyCode {
        case UInt16(kVK_UpArrow):
            return moveSelectedFolderFromKeyboard(by: -1)
        case UInt16(kVK_DownArrow):
            return moveSelectedFolderFromKeyboard(by: 1)
        default:
            return false
        }
    }

    private func cancelActiveFavoritesInput() -> Bool {
        if isCreatingFolder || editingFolderID != nil {
            cancelFolderEditing()
            return true
        }

        if editingFavoriteID != nil {
            cancelFavoriteEditing()
            return true
        }

        if !query.isEmpty {
            query = ""
            return true
        }

        return false
    }

    private func beginRenamingSelectedEntry() -> Bool {
        if let selectedFavorite {
            beginRenamingFavorite(selectedFavorite)
            return true
        }

        guard let selectedFolder else {
            return false
        }

        beginRenamingFolder(selectedFolder)
        return true
    }

    private func requestDeletingSelectedEntry() -> Bool {
        if model.selectedFavoriteID != nil {
            requestRemoveSelectedFavorite()
            return true
        }

        guard selectedFolder != nil else {
            return false
        }

        requestDeleteSelectedFolder()
        return true
    }

    private func moveSelectedFolderFromKeyboard(by offset: Int) -> Bool {
        guard selectedFolder != nil else {
            return false
        }

        model.moveSelectedFolder(by: offset)
        return true
    }

    private var selectedFolder: FavoriteFolder? {
        guard case let .folder(folderID) = model.selectedFolderFilter else {
            return nil
        }

        return model.folders.first { $0.id == folderID }
    }
}
