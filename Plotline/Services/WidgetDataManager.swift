import Foundation

/// Bridge between the main app and widget/intent extensions via shared UserDefaults
enum WidgetDataManager {
    private static let suiteName = "group.com.jbgsoft.Plotline"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Keys

    private enum Key {
        static let trending = "widget_trending"
        static let watchlistStats = "widget_watchlist_stats"
        static let dailyPick = "widget_daily_pick"
        static let statsSnapshot = "widget_stats_snapshot"
    }

    // MARK: - Generic Helpers

    private static func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        sharedDefaults?.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = sharedDefaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Trending

    static func updateTrending(_ items: [WidgetTrendingItem]) {
        save(items, forKey: Key.trending)
    }

    static func loadTrending() -> [WidgetTrendingItem] {
        load([WidgetTrendingItem].self, forKey: Key.trending) ?? []
    }

    // MARK: - Watchlist Stats

    static func updateWatchlistStats(_ stats: WidgetWatchlistStats) {
        save(stats, forKey: Key.watchlistStats)
    }

    static func loadWatchlistStats() -> WidgetWatchlistStats? {
        load(WidgetWatchlistStats.self, forKey: Key.watchlistStats)
    }

    // MARK: - Daily Pick

    static func updateDailyPick(_ pick: WidgetDailyPick) {
        save(pick, forKey: Key.dailyPick)
    }

    static func loadDailyPick() -> WidgetDailyPick? {
        load(WidgetDailyPick.self, forKey: Key.dailyPick)
    }

    // MARK: - Stats Snapshot

    static func updateStatsSnapshot(_ snapshot: WidgetStatsSnapshot) {
        save(snapshot, forKey: Key.statsSnapshot)
    }

    static func loadStatsSnapshot() -> WidgetStatsSnapshot? {
        load(WidgetStatsSnapshot.self, forKey: Key.statsSnapshot)
    }

    // MARK: - Poster Image Caching

    private static var imagesCacheDirectory: URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ) else { return nil }
        let imagesDir = containerURL.appendingPathComponent("WidgetImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        return imagesDir
    }

    /// Download and cache a poster image to the shared app group container.
    static func cacheImage(posterPath: String) async {
        let url = URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)")!
        guard let cacheDir = imagesCacheDirectory else { return }
        let fileURL = cacheDir.appendingPathComponent(posterPath.replacingOccurrences(of: "/", with: "_"))

        // Skip if already cached
        if FileManager.default.fileExists(atPath: fileURL.path) { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("Widget image cache failed for \(posterPath): \(error)")
            #endif
        }
    }

    /// Cache multiple poster images concurrently.
    static func cacheImages(posterPaths: [String?]) async {
        await withTaskGroup(of: Void.self) { group in
            for path in posterPaths.compactMap({ $0 }) {
                group.addTask {
                    await cacheImage(posterPath: path)
                }
            }
        }
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
