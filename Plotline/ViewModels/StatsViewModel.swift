import Foundation

/// Computes personal analytics from favorites and watchlist data
@Observable
final class StatsViewModel {
    // MARK: - Overview

    var totalFavorites = 0
    var totalWatchlist = 0
    var watchedCount = 0
    var wantToWatchCount = 0
    var completionRate: Double = 0

    // MARK: - Media Type Split

    var moviesCount = 0
    var seriesCount = 0

    // MARK: - Rating Distribution

    var ratingBuckets: [RatingBucket] = []

    // MARK: - Genre Breakdown

    var topGenres: [GenreStat] = []

    // MARK: - Activity Timeline

    var activityPoints: [ActivityPoint] = []

    // MARK: - Averages

    var favoritesAvgRating: Double = 0
    var watchlistAvgRating: Double = 0
    var watchedAvgRating: Double = 0

    var isEmpty: Bool {
        totalFavorites == 0 && totalWatchlist == 0
    }

    // MARK: - Computation

    func computeStats(favorites: [FavoriteItem], watchlistItems: [WatchlistItem]) {
        totalFavorites = favorites.count
        totalWatchlist = watchlistItems.count
        let watched = watchlistItems.filter { $0.watchStatus == "watched" }
        let wantToWatch = watchlistItems.filter { $0.watchStatus == "want_to_watch" }
        watchedCount = watched.count
        wantToWatchCount = wantToWatch.count
        completionRate = totalWatchlist > 0 ? Double(watchedCount) / Double(totalWatchlist) * 100 : 0

        computeMediaTypeSplit(favorites: favorites, watchlistItems: watchlistItems)
        computeRatingDistribution(favorites: favorites, watchlistItems: watchlistItems)
        computeGenreBreakdown(favorites: favorites, watchlistItems: watchlistItems)
        computeActivityTimeline(favorites: favorites, watchlistItems: watchlistItems)

        favoritesAvgRating = average(of: favorites.map(\.voteAverage))
        watchlistAvgRating = average(of: watchlistItems.map(\.voteAverage))
        watchedAvgRating = average(of: watched.map(\.voteAverage))
    }

    // MARK: - Private Computation

    private func average(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func computeMediaTypeSplit(favorites: [FavoriteItem], watchlistItems: [WatchlistItem]) {
        var movieIds = Set<Int>()
        var seriesIds = Set<Int>()

        for item in favorites {
            if item.mediaType == "movie" { movieIds.insert(item.tmdbId) }
            else { seriesIds.insert(item.tmdbId) }
        }
        for item in watchlistItems {
            if item.mediaType == "movie" { movieIds.insert(item.tmdbId) }
            else { seriesIds.insert(item.tmdbId) }
        }
        moviesCount = movieIds.count
        seriesCount = seriesIds.count
    }

    private func computeRatingDistribution(favorites: [FavoriteItem], watchlistItems: [WatchlistItem]) {
        var buckets = [0, 0, 0, 0, 0]
        let allRatings = favorites.map(\.voteAverage) + watchlistItems.map(\.voteAverage)
        for rating in allRatings {
            switch rating {
            case 0..<3: buckets[0] += 1
            case 3..<5: buckets[1] += 1
            case 5..<7: buckets[2] += 1
            case 7..<9: buckets[3] += 1
            default: buckets[4] += 1
            }
        }
        let bucketLabels = ["0-2", "3-4", "5-6", "7-8", "9-10"]
        ratingBuckets = zip(bucketLabels, buckets).map { RatingBucket(label: $0, count: $1) }
    }

    private func computeGenreBreakdown(favorites: [FavoriteItem], watchlistItems: [WatchlistItem]) {
        var genreCounts: [Int: Int] = [:]
        for item in favorites {
            for gid in item.genreIdArray { genreCounts[gid, default: 0] += 1 }
        }
        for item in watchlistItems {
            for gid in item.genreIdArray { genreCounts[gid, default: 0] += 1 }
        }
        topGenres = genreCounts
            .compactMap { id, count in
                guard let name = GenreLookup.name(for: id) else { return nil }
                return GenreStat(name: name, count: count)
            }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }
    }

    private func computeActivityTimeline(favorites: [FavoriteItem], watchlistItems: [WatchlistItem]) {
        let calendar = Calendar.current
        let now = Date()
        var weekCounts: [Date: Int] = [:]

        let allDates = favorites.map(\.addedAt) + watchlistItems.map(\.addedAt)
        for date in allDates {
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
                weekCounts[weekStart, default: 0] += 1
            }
        }

        let twelveWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        activityPoints = weekCounts
            .filter { $0.key >= twelveWeeksAgo }
            .sorted { $0.key < $1.key }
            .map { ActivityPoint(week: $0.key, count: $0.value) }
    }
}

// MARK: - Supporting Types

struct RatingBucket: Identifiable {
    var id: String { label }
    let label: String
    let count: Int
}

struct GenreStat: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

struct ActivityPoint: Identifiable {
    var id: Date { week }
    let week: Date
    let count: Int
}
