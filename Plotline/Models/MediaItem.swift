import Foundation

/// Unified model representing both movies and TV series from TMDB
struct MediaItem: Identifiable, Codable, Hashable {
    let id: Int
    var overview: String
    var posterPath: String?
    var backdropPath: String?
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

    // Movie-specific enriched data
    var budget: Int?
    var revenue: Int?
    var collectionId: Int?
    var collectionName: String?
    var awards: String?

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

    /// Box office data computed from budget and revenue
    var boxOffice: BoxOfficeData? {
        guard let budget = budget, let revenue = revenue else { return nil }
        let data = BoxOfficeData(budget: budget, revenue: revenue)
        return data.hasData ? data : nil
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
        case budget
        case revenue
        case collectionId
        case collectionName
        case awards
    }

    // MARK: - Custom Decoder (handles missing fields from person results)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage) ?? 0
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount) ?? 0
        genreIds = try container.decodeIfPresent([Int].self, forKey: .genreIds)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        mediaType = try container.decodeIfPresent(MediaType.self, forKey: .mediaType)
        imdbId = try container.decodeIfPresent(String.self, forKey: .imdbId)
        externalRatings = try container.decodeIfPresent([RatingSource].self, forKey: .externalRatings)
        seasonEpisodes = try container.decodeIfPresent([EpisodeMetric].self, forKey: .seasonEpisodes)
        totalSeasons = try container.decodeIfPresent(Int.self, forKey: .totalSeasons)
        budget = try container.decodeIfPresent(Int.self, forKey: .budget)
        revenue = try container.decodeIfPresent(Int.self, forKey: .revenue)
        collectionId = try container.decodeIfPresent(Int.self, forKey: .collectionId)
        collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName)
        awards = try container.decodeIfPresent(String.self, forKey: .awards)
    }

    // MARK: - Memberwise Initializer

    init(
        id: Int,
        overview: String,
        posterPath: String?,
        backdropPath: String?,
        voteAverage: Double,
        voteCount: Int,
        genreIds: [Int]?,
        title: String?,
        releaseDate: String?,
        name: String?,
        firstAirDate: String?,
        mediaType: MediaType?,
        imdbId: String? = nil,
        externalRatings: [RatingSource]? = nil,
        seasonEpisodes: [EpisodeMetric]? = nil,
        totalSeasons: Int? = nil,
        budget: Int? = nil,
        revenue: Int? = nil,
        collectionId: Int? = nil,
        collectionName: String? = nil,
        awards: String? = nil
    ) {
        self.id = id
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.genreIds = genreIds
        self.title = title
        self.releaseDate = releaseDate
        self.name = name
        self.firstAirDate = firstAirDate
        self.mediaType = mediaType
        self.imdbId = imdbId
        self.externalRatings = externalRatings
        self.seasonEpisodes = seasonEpisodes
        self.totalSeasons = totalSeasons
        self.budget = budget
        self.revenue = revenue
        self.collectionId = collectionId
        self.collectionName = collectionName
        self.awards = awards
    }
}

// MARK: - Media Type

enum MediaType: String, Codable, Hashable {
    case movie
    case tv
    case person  // Returned by multi-search, filtered out in app

    var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .tv: return "TV Series"
        case .person: return "Person"
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
