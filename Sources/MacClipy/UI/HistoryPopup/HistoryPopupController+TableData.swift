import AppKit

extension HistoryPopupController {
    func numberOfRows(in tableView: NSTableView) -> Int {
        results.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard results.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("historyPopupCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? HistoryPopupCellView
            ?? HistoryPopupCellView(identifier: identifier)
        let result = results[row]
        cell.configure(
            title: popupTitle(for: result),
            detail: popupDetail(for: result),
            content: result.item.content,
            isFavorite: result.favorite != nil
        )
        cell.onToggleFavorite = { [weak self] in
            self?.toggleFavorite(at: row)
        }
        return cell
    }

    private func popupTitle(for result: PopupResult) -> String {
        result.favorite?.menuTitle ?? result.item.menuTitle
    }

    private func popupDetail(for result: PopupResult) -> String? {
        guard let favorite = result.favorite, favorite.hasCustomDisplayTitle else {
            return nil
        }
        return favorite.contentMenuTitle
    }
}
