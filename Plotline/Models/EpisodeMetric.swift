import Foundation

/// Represents episode rating data for the SeriesGraph and the analysis engine.
///
/// Ratings come from TMDB's season endpoint. `voteCount` is kept because the
/// analysis engine weights episodes by how many votes back them up.
struct EpisodeMetric: Identifiable, Codable, Hashable {
    /// TMDB's stable episode id. Kept verbatim so an episode keeps the same
    /// `Identifiable` id whether it came from the network or from `DiskCache`.
    let id: Int
    let episodeNumber: Int
    let seasonNumber: Int
    let title: String
    let rating: Double
    let voteCount: Int
    let airDate: String?
    let stillPath: String?

    // MARK: - Computed Properties

    /// Formatted rating string (e.g., "8.5"), or an em dash when unrated.
    var formattedRating: String {
        rating > 0 ? String(format: "%.1f", rating) : "—"
    }

    /// Display string for episode (e.g., "S1E5")
    var shortCode: String {
        "S\(seasonNumber)E\(episodeNumber)"
    }

    /// Full display string (e.g., "Season 1, Episode 5")
    var fullCode: String {
        "Season \(seasonNumber), Episode \(episodeNumber)"
    }

    /// A rating only counts when it is positive and backed by at least one vote.
    var hasValidRating: Bool {
        rating > 0 && voteCount > 0
    }

    /// Whether the episode has already aired. Episodes without an air date are
    /// treated as unaired so they never reach the analysis engine.
    var hasAired: Bool {
        hasAired(asOf: Date())
    }

    /// Air check against an explicit reference date, so the analysis engine
    /// stays a pure function of its inputs and its tests never depend on the clock.
    func hasAired(asOf date: Date) -> Bool {
        guard let airDate, let aired = Self.airDateFormatter.date(from: airDate) else {
            return false
        }
        return aired <= date
    }

    /// Whether the episode is scheduled to air after the given date.
    ///
    /// Not the inverse of `hasAired(asOf:)`: an episode with a missing or
    /// unparseable air date has not aired *and* is not scheduled, so it is
    /// evidence of nothing. TMDB returns null air dates routinely, and treating
    /// those as upcoming would keep a finished series looking unfinished
    /// forever.
    func airsAfter(_ date: Date) -> Bool {
        guard let airDate, let aired = Self.airDateFormatter.date(from: airDate) else {
            return false
        }
        return aired > date
    }

    /// URL for the episode still image.
    var stillURL: URL? {
        TMDBService.backdropURL(path: stillPath, size: .small)
    }

    // MARK: - Initializers

    /// - Parameter id: TMDB's episode id. When omitted (preview and test data) a
    ///   deterministic id is derived from the season/episode pair, so identity is
    ///   still stable across encode/decode round trips.
    init(
        id: Int? = nil,
        episodeNumber: Int,
        seasonNumber: Int,
        title: String,
        rating: Double,
        voteCount: Int,
        airDate: String? = nil,
        stillPath: String? = nil
    ) {
        self.id = id ?? (seasonNumber * 1_000 + episodeNumber)
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.title = title
        self.rating = rating
        self.voteCount = voteCount
        self.airDate = airDate
        self.stillPath = stillPath
    }

    // MARK: - Private

    private static let airDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Preview Data

extension EpisodeMetric {
    static let preview = EpisodeMetric(
        episodeNumber: 1,
        seasonNumber: 1,
        title: "Pilot",
        rating: 8.9,
        voteCount: 412,
        airDate: "2008-01-20"
    )

    /// Sample data for Breaking Bad Season 1
    static let breakingBadS1: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 1, title: "Pilot", rating: 9.0, voteCount: 412, airDate: "2008-01-20"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 1, title: "Cat's in the Bag...", rating: 8.5, voteCount: 305, airDate: "2008-01-27"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 1, title: "...And the Bag's in the River", rating: 8.7, voteCount: 291, airDate: "2008-02-10"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 1, title: "Cancer Man", rating: 8.2, voteCount: 274, airDate: "2008-02-17"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 1, title: "Gray Matter", rating: 8.3, voteCount: 268, airDate: "2008-02-24"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 1, title: "Crazy Handful of Nothin'", rating: 9.2, voteCount: 289, airDate: "2008-03-02"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 1, title: "A No-Rough-Stuff-Type Deal", rating: 8.8, voteCount: 271, airDate: "2008-03-09")
    ]

    /// Sample data for Breaking Bad Season 5
    static let breakingBadS5: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 5, title: "Live Free or Die", rating: 9.1, voteCount: 251, airDate: "2012-07-15"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 5, title: "Madrigal", rating: 8.7, voteCount: 233, airDate: "2012-07-22"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 5, title: "Hazard Pay", rating: 8.8, voteCount: 228, airDate: "2012-07-29"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 5, title: "Fifty-One", rating: 8.8, voteCount: 224, airDate: "2012-08-05"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 5, title: "Dead Freight", rating: 9.7, voteCount: 246, airDate: "2012-08-12"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 5, title: "Buyout", rating: 9.1, voteCount: 221, airDate: "2012-08-19"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 5, title: "Say My Name", rating: 9.4, voteCount: 239, airDate: "2012-08-26"),
        EpisodeMetric(episodeNumber: 8, seasonNumber: 5, title: "Gliding Over All", rating: 9.6, voteCount: 244, airDate: "2012-09-02"),
        EpisodeMetric(episodeNumber: 9, seasonNumber: 5, title: "Blood Money", rating: 9.3, voteCount: 258, airDate: "2013-08-11"),
        EpisodeMetric(episodeNumber: 10, seasonNumber: 5, title: "Buried", rating: 9.2, voteCount: 241, airDate: "2013-08-18"),
        EpisodeMetric(episodeNumber: 11, seasonNumber: 5, title: "Confessions", rating: 9.5, voteCount: 249, airDate: "2013-08-25"),
        EpisodeMetric(episodeNumber: 12, seasonNumber: 5, title: "Rabid Dog", rating: 9.0, voteCount: 236, airDate: "2013-09-01"),
        EpisodeMetric(episodeNumber: 13, seasonNumber: 5, title: "To'hajiilee", rating: 9.8, voteCount: 279, airDate: "2013-09-08"),
        EpisodeMetric(episodeNumber: 14, seasonNumber: 5, title: "Ozymandias", rating: 10.0, voteCount: 412, airDate: "2013-09-15"),
        EpisodeMetric(episodeNumber: 15, seasonNumber: 5, title: "Granite State", rating: 9.6, voteCount: 268, airDate: "2013-09-22"),
        EpisodeMetric(episodeNumber: 16, seasonNumber: 5, title: "Felina", rating: 9.9, voteCount: 355, airDate: "2013-09-29")
    ]
}
