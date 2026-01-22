import Foundation

/// Represents episode rating data for the SeriesGraph
struct EpisodeMetric: Identifiable, Codable, Hashable {
    let id: UUID
    let episodeNumber: Int
    let seasonNumber: Int
    let title: String
    let imdbRating: String
    let imdbId: String?

    // MARK: - Computed Properties

    /// Cleaned rating string (trimmed whitespace)
    private var cleanedRating: String {
        imdbRating.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Rating as Double for Swift Charts
    var rating: Double {
        Double(cleanedRating) ?? 0.0
    }

    /// Formatted rating string (e.g., "8.5")
    var formattedRating: String {
        if let value = Double(cleanedRating) {
            return String(format: "%.1f", value)
        }
        return imdbRating
    }

    /// Display string for episode (e.g., "S1E5")
    var shortCode: String {
        "S\(seasonNumber)E\(episodeNumber)"
    }

    /// Full display string (e.g., "Season 1, Episode 5")
    var fullCode: String {
        "Season \(seasonNumber), Episode \(episodeNumber)"
    }

    /// Checks if rating data is valid (not N/A and parses to a positive number)
    var hasValidRating: Bool {
        let invalidValues: Set<String> = ["", "n/a", "na", "-"]
        return !invalidValues.contains(cleanedRating.lowercased()) && rating > 0.0
    }

    /// URL to the episode's IMDb page
    var imdbURL: URL? {
        guard let imdbId else { return nil }
        return URL(string: "https://www.imdb.com/title/\(imdbId)/")
    }

    // MARK: - Initializers

    init(id: UUID = UUID(), episodeNumber: Int, seasonNumber: Int, title: String, imdbRating: String, imdbId: String? = nil) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.title = title
        self.imdbRating = imdbRating
        self.imdbId = imdbId
    }
}

// MARK: - Preview Data

extension EpisodeMetric {
    static let preview = EpisodeMetric(
        episodeNumber: 1,
        seasonNumber: 1,
        title: "Pilot",
        imdbRating: "8.9",
        imdbId: "tt0959621"
    )

    /// Sample data for Breaking Bad Season 1
    static let breakingBadS1: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 1, title: "Pilot", imdbRating: "9.0", imdbId: "tt0959621"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 1, title: "Cat's in the Bag...", imdbRating: "8.5", imdbId: "tt1054724"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 1, title: "...And the Bag's in the River", imdbRating: "8.7", imdbId: "tt1054725"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 1, title: "Cancer Man", imdbRating: "8.2", imdbId: "tt1054726"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 1, title: "Gray Matter", imdbRating: "8.3", imdbId: "tt1054727"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 1, title: "Crazy Handful of Nothin'", imdbRating: "9.2", imdbId: "tt1054728"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 1, title: "A No-Rough-Stuff-Type Deal", imdbRating: "8.8", imdbId: "tt1054729")
    ]

    /// Sample data for Breaking Bad Season 5
    static let breakingBadS5: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 5, title: "Live Free or Die", imdbRating: "9.1", imdbId: "tt2081647"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 5, title: "Madrigal", imdbRating: "8.7", imdbId: "tt2081648"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 5, title: "Hazard Pay", imdbRating: "8.8", imdbId: "tt2081649"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 5, title: "Fifty-One", imdbRating: "8.8", imdbId: "tt2081650"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 5, title: "Dead Freight", imdbRating: "9.7", imdbId: "tt2301451"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 5, title: "Buyout", imdbRating: "9.1", imdbId: "tt2301452"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 5, title: "Say My Name", imdbRating: "9.4", imdbId: "tt2301453"),
        EpisodeMetric(episodeNumber: 8, seasonNumber: 5, title: "Gliding Over All", imdbRating: "9.6", imdbId: "tt2301454"),
        EpisodeMetric(episodeNumber: 9, seasonNumber: 5, title: "Blood Money", imdbRating: "9.3", imdbId: "tt2639950"),
        EpisodeMetric(episodeNumber: 10, seasonNumber: 5, title: "Buried", imdbRating: "9.2", imdbId: "tt2639952"),
        EpisodeMetric(episodeNumber: 11, seasonNumber: 5, title: "Confessions", imdbRating: "9.5", imdbId: "tt2639954"),
        EpisodeMetric(episodeNumber: 12, seasonNumber: 5, title: "Rabid Dog", imdbRating: "9.0", imdbId: "tt2639956"),
        EpisodeMetric(episodeNumber: 13, seasonNumber: 5, title: "To'hajiilee", imdbRating: "9.8", imdbId: "tt2639958"),
        EpisodeMetric(episodeNumber: 14, seasonNumber: 5, title: "Ozymandias", imdbRating: "10.0", imdbId: "tt2301451"),
        EpisodeMetric(episodeNumber: 15, seasonNumber: 5, title: "Granite State", imdbRating: "9.6", imdbId: "tt2639962"),
        EpisodeMetric(episodeNumber: 16, seasonNumber: 5, title: "Felina", imdbRating: "9.9", imdbId: "tt2639964")
    ]
}
