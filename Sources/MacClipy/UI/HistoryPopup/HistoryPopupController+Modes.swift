import AppKit

extension HistoryPopupController {
    @objc func changeFilterMode() {
        setMode(filterSegment.selectedSegment == PopupMode.favorites.rawValue ? .favorites : .all)
    }

    func toggleFavoriteMode() {
        setMode(mode == .favorites ? .all : .favorites)
    }

    func setMode(_ nextMode: PopupMode) {
        mode = nextMode
        filterSegment.selectedSegment = mode.rawValue
        folderPopup.isEnabled = mode == .favorites
        reloadResults()
    }
}
