import AppIntents
import SwiftData

/// Siri intent that returns a text summary of the user's stats without opening the app
struct ShowMyStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Stats"
    static var description = IntentDescription("See a summary of your Plotline collection")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = try? ModelContainer(for: FavoriteItem.self, WatchlistItem.self) else {
            return .result(dialog: "No stats available yet. Open Plotline and add some favorites!")
        }

        let context = container.mainContext

        let favorites = (try? context.fetch(FetchDescriptor<FavoriteItem>())) ?? []
        let watchlist = (try? context.fetch(FetchDescriptor<WatchlistItem>())) ?? []

        let totalFavorites = favorites.count
        let totalWatchlist = watchlist.count
        let watchedCount = watchlist.filter { $0.watchStatus == "watched" }.count
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
