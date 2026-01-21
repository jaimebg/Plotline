import Foundation

/// Unified model representing both movies and TV series from TMDB
struct MediaItem: Identifiable, Codable, Hashable {
    let id: Int
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    let genreIds: [Int]?

    // Movie-specific fields
    let title: String?
    let releaseDate: String?

    // TV-specific fields
    let name: String?
    let firstAirDate: String?

    // Media type (from multi search or manually set)
    let mediaType: MediaType?

    // External IDs (populated from detail endpoint)
    var imdbId: String?

    // Enriched data from OMDb (injected asynchronously)
    var externalRatings: [RatingSource]?
    var seasonEpisodes: [EpisodeMetric]?
    var totalSeasons: Int?

    // MARK: - Computed Properties

    /// Display title (works for both movies and TV)
    var displayTitle: String {
        title ?? name ?? "Unknown"
    }

    /// Display date (works for both movies and TV)
    var displayDate: String? {
        releaseDate ?? firstAirDate
    }

    /// Year extracted from date
    var year: String? {
        guard let date = displayDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    /// Full poster URL for TMDB images
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    /// Full backdrop URL for TMDB images
    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/original\(path)")
    }

    /// Formatted vote average (e.g., "8.5")
    var formattedRating: String {
        String(format: "%.1f", voteAverage)
    }

    /// Determines if this is a TV series
    var isTVSeries: Bool {
        mediaType == .tv || name != nil
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case overview
        case posterPath
        case backdropPath
        case voteAverage
        case voteCount
        case genreIds
        case title
        case releaseDate
        case name
        case firstAirDate
        case mediaType
        case imdbId
        case externalRatings
        case seasonEpisodes
        case totalSeasons
    }
}

// MARK: - Media Type

enum MediaType: String, Codable, Hashable {
    case movie
    case tv

    var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .tv: return "TV Series"
        }
    }
}

// MARK: - Preview Data

extension MediaItem {
    static let preview = MediaItem(
        id: 1396,
        overview: "A chemistry teacher diagnosed with inoperable lung cancer turns to manufacturing and selling methamphetamine with a former student to secure his family's future.",
        posterPath: "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
        backdropPath: "/tsRy63Mu5cu8etL1X7ZLyf7UFy8.jpg",
        voteAverage: 8.9,
        voteCount: 12000,
        genreIds: [18, 80],
        title: nil,
        releaseDate: nil,
        name: "Breaking Bad",
        firstAirDate: "2008-01-20",
        mediaType: .tv,
        imdbId: "tt0903747",
        externalRatings: nil,
        seasonEpisodes: nil,
        totalSeasons: 5
    )

    static let moviePreview = MediaItem(
        id: 550,
        overview: "A ticking-Loss adjuster clock. An enigmatic madhouse. A sensual obsessive. And a cryptic enigma from the past.",
        posterPath: "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
        backdropPath: "/rr7E0NoGKxvbkb89eR1GwfoYjpA.jpg",
        voteAverage: 8.4,
        voteCount: 25000,
        genreIds: [18, 53],
        title: "Fight Club",
        releaseDate: "1999-10-15",
        name: nil,
        firstAirDate: nil,
        mediaType: .movie,
        imdbId: "tt0137523",
        externalRatings: nil,
        seasonEpisodes: nil,
        totalSeasons: nil
    )
}
