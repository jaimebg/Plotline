import AppIntents

/// Siri intent that returns a text summary of the user's stats without opening the app
struct ShowMyStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Stats"
    static var description = IntentDescription("See a summary of your Plotline collection")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = WidgetDataManager.loadStatsSnapshot() else {
            return .result(dialog: "No stats available yet. Open Plotline and add some favorites!")
        }

        var parts: [String] = []

        if snapshot.totalFavorites > 0 {
            parts.append("\(snapshot.totalFavorites) \(pluralize("favorite", count: snapshot.totalFavorites))")
        }
        if snapshot.totalWatchlist > 0 {
            parts.append("\(snapshot.totalWatchlist) \(pluralize("item", count: snapshot.totalWatchlist)) on your watchlist")
        }
        if snapshot.watchedCount > 0 {
            parts.append("\(snapshot.watchedCount) watched")
        }

        if parts.isEmpty {
            return .result(dialog: "Your collection is empty. Open Plotline to start discovering!")
        }

        let avgFormatted = String(format: "%.1f", snapshot.averageRating)
        let summary = "You have \(parts.joined(separator: ", ")). " +
            "\(snapshot.moviesCount) \(pluralize("movie", count: snapshot.moviesCount)) and " +
            "\(snapshot.seriesCount) series with an average rating of \(avgFormatted)."

        return .result(dialog: "\(summary)")
    }

    private func pluralize(_ word: String, count: Int) -> String {
        count == 1 ? word : "\(word)s"
    }
}
