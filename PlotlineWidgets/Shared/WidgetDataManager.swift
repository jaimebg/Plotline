import Foundation
import UIKit

/// Bridge between the main app and widget extensions via shared UserDefaults (widget copy)
enum WidgetDataManager {
    private static let suiteName = "group.com.jbgsoft.Plotline"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private enum Key {
        static let trending = "widget_trending"
        static let watchlistStats = "widget_watchlist_stats"
        static let dailyPick = "widget_daily_pick"
        static let statsSnapshot = "widget_stats_snapshot"
    }

    static func loadTrending() -> [WidgetTrendingItem] {
        guard let data = sharedDefaults?.data(forKey: Key.trending),
              let items = try? JSONDecoder().decode([WidgetTrendingItem].self, from: data) else {
            return []
        }
        return items
    }

    static func loadWatchlistStats() -> WidgetWatchlistStats? {
        guard let data = sharedDefaults?.data(forKey: Key.watchlistStats),
              let stats = try? JSONDecoder().decode(WidgetWatchlistStats.self, from: data) else {
            return nil
        }
        return stats
    }

    static func loadDailyPick() -> WidgetDailyPick? {
        guard let data = sharedDefaults?.data(forKey: Key.dailyPick),
              let pick = try? JSONDecoder().decode(WidgetDailyPick.self, from: data) else {
            return nil
        }
        return pick
    }

    static func loadStatsSnapshot() -> WidgetStatsSnapshot? {
        guard let data = sharedDefaults?.data(forKey: Key.statsSnapshot),
              let snapshot = try? JSONDecoder().decode(WidgetStatsSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    // MARK: - Cached Poster Images

    static func loadCachedImage(posterPath: String?) -> UIImage? {
        guard let posterPath else { return nil }
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ) else { return nil }
        let fileURL = containerURL
            .appendingPathComponent("WidgetImages", isDirectory: true)
            .appendingPathComponent(posterPath.replacingOccurrences(of: "/", with: "_"))
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Shared Codable Types

struct WidgetTrendingItem: Codable {
    let tmdbId: Int
    let title: String
    let posterPath: String?
    let voteAverage: Double
    let mediaType: String
    let year: String?
}

struct WidgetWatchlistStats: Codable {
    let totalCount: Int
    let watchedCount: Int
    let wantToWatchCount: Int
}

struct WidgetDailyPick: Codable {
    let tmdbId: Int
    let title: String
    let posterPath: String?
    let voteAverage: Double
    let mediaType: String
    let basedOnTitle: String
}

struct WidgetStatsSnapshot: Codable {
    let totalFavorites: Int
    let totalWatchlist: Int
    let watchedCount: Int
    let moviesCount: Int
    let seriesCount: Int
    let averageRating: Double
}
