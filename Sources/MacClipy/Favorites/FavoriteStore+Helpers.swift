import Foundation

extension FavoriteStore {
    func nextSortOrder(for values: [FavoriteItem]) -> Int {
        values.map(\.sortOrder).max().map { $0 + AppConstants.Favorites.sortOrderStep }
            ?? AppConstants.Favorites.initialSortOrder
    }

    func nextSortOrder(for values: [FavoriteFolder]) -> Int {
        values.map(\.sortOrder).max().map { $0 + AppConstants.Favorites.sortOrderStep }
            ?? AppConstants.Favorites.initialSortOrder
    }

    func resolvedDisplayTitle(for content: String, displayTitle: String?) -> String {
        let trimmedTitle = displayTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedTitle, !trimmedTitle.isEmpty else {
            return FavoriteItem.defaultDisplayTitle(for: content)
        }
        return trimmedTitle
    }
}
