import AppIntents
import SwiftData

/// Siri intent that returns a text summary of the user's stats without opening the app
struct ShowMyStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Stats"
    static var description = IntentDescription("See a summary of your Plotline collection")
    static var openAppWhenRun = false

    /// The app's shared container, registered in `PlotlineApp.init()`.
    ///
    /// Building a container here with default settings opened a second
    /// CloudKit mirror on the same store.
    @Dependency
    private var modelContainer: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = modelContainer.mainContext

        let allFavorites = (try? context.fetch(FetchDescriptor<FavoriteItem>())) ?? []
        let allWatchlist = (try? context.fetch(FetchDescriptor<WatchlistItem>())) ?? []

        // CloudKit can hold several records for one title until the app next
        // collapses them; count titles, not records. Same survivor and merge
        // rule as the managers, without writing anything from Siri.
        let favorites = DuplicateResolver.group(allFavorites, id: \.tmdbId, addedAt: \.addedAt)
            .map(\.keeper)
        let watchlistGroups = DuplicateResolver.group(allWatchlist, id: \.tmdbId, addedAt: \.addedAt)
        let watchlistStatuses = watchlistGroups.map { group in
            DuplicateResolver.mostAdvancedWatchStatus(([group.keeper] + group.duplicates).map(\.watchStatus))
        }

        let totalFavorites = favorites.count
        let totalWatchlist = watchlistStatuses.count
        let watchedCount = watchlistStatuses.filter { $0 == "watched" }.count
        let moviesCount = favorites.filter { $0.mediaType == "movie" }.count
        let seriesCount = favorites.filter { $0.mediaType == "tv" }.count
        let averageRating = favorites.isEmpty ? 0.0 : favorites.map(\.voteAverage).reduce(0, +) / Double(favorites.count)

        var parts: [String] = []

        if totalFavorites > 0 {
            parts.append("\(totalFavorites) \(pluralize("favorite", count: totalFavorites))")
        }
        if totalWatchlist > 0 {
            parts.append("\(totalWatchlist) \(pluralize("item", count: totalWatchlist)) on your watchlist")
        }
        if watchedCount > 0 {
            parts.append("\(watchedCount) watched")
        }

        if parts.isEmpty {
            return .result(dialog: "Your collection is empty. Open Plotline to start discovering!")
        }

        let avgFormatted = String(format: "%.1f", averageRating)
        let summary = "You have \(parts.joined(separator: ", ")). " +
            "\(moviesCount) \(pluralize("movie", count: moviesCount)) and " +
            "\(seriesCount) series with an average rating of \(avgFormatted)."

        return .result(dialog: "\(summary)")
    }

    private func pluralize(_ word: String, count: Int) -> String {
        count == 1 ? word : "\(word)s"
    }
}
