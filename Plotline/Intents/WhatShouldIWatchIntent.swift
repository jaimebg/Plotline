import AppIntents
import SwiftData

/// Siri intent that suggests a random unwatched item from the user's watchlist
struct WhatShouldIWatchIntent: AppIntent {
    static var title: LocalizedStringResource = "What Should I Watch?"
    static var description = IntentDescription("Get a random suggestion from your watchlist")
    static var openAppWhenRun = true

    @Dependency
    private var modelContainer: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<WatchlistItem>(
            predicate: #Predicate { $0.watchStatus == "want_to_watch" }
        )

        guard let items = try? context.fetch(descriptor), !items.isEmpty else {
            return .result(dialog: "Your watchlist is empty. Open Plotline to discover new titles!")
        }

        if let pick = items.randomElement() {
            let rating = String(format: "%.1f", pick.voteAverage)
            let type = pick.isTVSeries ? "series" : "movie"
            return .result(dialog: "How about \(pick.title)? It's a \(type) with a \(rating) rating!")
        }

        return .result(dialog: "Open Plotline to browse your watchlist!")
    }
}
