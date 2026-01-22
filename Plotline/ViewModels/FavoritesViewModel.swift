import Foundation
import SwiftData

/// Filter options for favorites list
enum FavoriteFilter: String, CaseIterable {
    case all = "All"
    case movies = "Movies"
    case series = "Series"
}

/// Sort options for favorites list
enum FavoriteSort: String, CaseIterable {
    case dateAdded = "Date Added"
    case rating = "Rating"
    case alphabetical = "A-Z"

    var icon: String {
        switch self {
        case .dateAdded: return "calendar"
        case .rating: return "star.fill"
        case .alphabetical: return "textformat.abc"
        }
    }
}

/// ViewModel for the Favorites screen
@Observable
final class FavoritesViewModel {
    var filter: FavoriteFilter = .all
    var sort: FavoriteSort = .dateAdded

    /// Filter and sort the favorites array based on current settings
    func filteredAndSorted(_ favorites: [FavoriteItem]) -> [FavoriteItem] {
        var result = favorites

        // Apply filter
        switch filter {
        case .all:
            break
        case .movies:
            result = result.filter { !$0.isTVSeries }
        case .series:
            result = result.filter { $0.isTVSeries }
        }

        // Apply sort
        switch sort {
        case .dateAdded:
            result.sort { $0.addedAt > $1.addedAt }
        case .rating:
            result.sort { $0.voteAverage > $1.voteAverage }
        case .alphabetical:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        return result
    }
}
