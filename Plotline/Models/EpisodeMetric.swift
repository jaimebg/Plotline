import Foundation

/// Represents episode rating data for the SeriesGraph
struct EpisodeMetric: Identifiable, Codable, Hashable {
    let id: UUID
    let episodeNumber: Int
    let seasonNumber: Int
    let title: String
    let imdbRating: String

    // MARK: - Computed Properties

    /// Rating as Double for Swift Charts
    var rating: Double {
        Double(imdbRating) ?? 0.0
    }

    /// Formatted rating string (e.g., "8.5")
    var formattedRating: String {
        if let value = Double(imdbRating) {
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

    /// Checks if rating data is valid
    var hasValidRating: Bool {
        rating > 0.0 && imdbRating.lowercased() != "n/a"
    }

    // MARK: - Initializers

    init(id: UUID = UUID(), episodeNumber: Int, seasonNumber: Int, title: String, imdbRating: String) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.title = title
        self.imdbRating = imdbRating
    }
}

// MARK: - Preview Data

extension EpisodeMetric {
    static let preview = EpisodeMetric(
        episodeNumber: 1,
        seasonNumber: 1,
        title: "Pilot",
        imdbRating: "8.9"
    )

    /// Sample data for Breaking Bad Season 1
    static let breakingBadS1: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 1, title: "Pilot", imdbRating: "9.0"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 1, title: "Cat's in the Bag...", imdbRating: "8.5"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 1, title: "...And the Bag's in the River", imdbRating: "8.7"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 1, title: "Cancer Man", imdbRating: "8.2"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 1, title: "Gray Matter", imdbRating: "8.3"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 1, title: "Crazy Handful of Nothin'", imdbRating: "9.2"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 1, title: "A No-Rough-Stuff-Type Deal", imdbRating: "8.8")
    ]

    /// Sample data for Breaking Bad Season 5
    static let breakingBadS5: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 5, title: "Live Free or Die", imdbRating: "9.1"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 5, title: "Madrigal", imdbRating: "8.7"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 5, title: "Hazard Pay", imdbRating: "8.8"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 5, title: "Fifty-One", imdbRating: "8.8"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 5, title: "Dead Freight", imdbRating: "9.7"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 5, title: "Buyout", imdbRating: "9.1"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 5, title: "Say My Name", imdbRating: "9.4"),
        EpisodeMetric(episodeNumber: 8, seasonNumber: 5, title: "Gliding Over All", imdbRating: "9.6"),
        EpisodeMetric(episodeNumber: 9, seasonNumber: 5, title: "Blood Money", imdbRating: "9.3"),
        EpisodeMetric(episodeNumber: 10, seasonNumber: 5, title: "Buried", imdbRating: "9.2"),
        EpisodeMetric(episodeNumber: 11, seasonNumber: 5, title: "Confessions", imdbRating: "9.5"),
        EpisodeMetric(episodeNumber: 12, seasonNumber: 5, title: "Rabid Dog", imdbRating: "9.0"),
        EpisodeMetric(episodeNumber: 13, seasonNumber: 5, title: "To'hajiilee", imdbRating: "9.8"),
        EpisodeMetric(episodeNumber: 14, seasonNumber: 5, title: "Ozymandias", imdbRating: "10.0"),
        EpisodeMetric(episodeNumber: 15, seasonNumber: 5, title: "Granite State", imdbRating: "9.6"),
        EpisodeMetric(episodeNumber: 16, seasonNumber: 5, title: "Felina", imdbRating: "9.9")
    ]
}
