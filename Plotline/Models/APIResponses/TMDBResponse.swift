import Foundation

/// Response wrapper for TMDB API list endpoints
struct TMDBResponse: Codable {
    let page: Int
    let results: [MediaItem]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages
        case totalResults
    }
}

/// Response for TMDB movie/tv detail with external IDs
struct TMDBDetailResponse: Codable {
    let id: Int
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    let genres: [Genre]?

    // Movie-specific
    let title: String?
    let releaseDate: String?
    let runtime: Int?

    // TV-specific
    let name: String?
    let firstAirDate: String?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?

    // External IDs (from append_to_response)
    let externalIds: ExternalIds?

    enum CodingKeys: String, CodingKey {
        case id
        case overview
        case posterPath
        case backdropPath
        case voteAverage
        case voteCount
        case genres
        case title
        case releaseDate
        case runtime
        case name
        case firstAirDate
        case numberOfSeasons
        case numberOfEpisodes
        case externalIds
    }

    /// Converts to MediaItem for unified handling
    func toMediaItem(mediaType: MediaType) -> MediaItem {
        MediaItem(
            id: id,
            overview: overview ?? "",
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIds: genres?.map(\.id),
            title: title,
            releaseDate: releaseDate,
            name: name,
            firstAirDate: firstAirDate,
            mediaType: mediaType,
            imdbId: externalIds?.imdbId,
            externalRatings: nil,
            seasonEpisodes: nil,
            totalSeasons: numberOfSeasons
        )
    }
}

/// Genre model from TMDB
struct Genre: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

/// External IDs from TMDB (IMDb, etc.)
struct ExternalIds: Codable {
    let imdbId: String?
    let facebookId: String?
    let instagramId: String?
    let twitterId: String?

    enum CodingKeys: String, CodingKey {
        case imdbId
        case facebookId
        case instagramId
        case twitterId
    }
}

/// Response for TMDB credits endpoint
struct TMDBCreditsResponse: Codable {
    let id: Int
    let cast: [CastMember]
    let crew: [CrewMember]
}

/// Cast member from TMDB
struct CastMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
    let order: Int

    var profileURL: URL? {
        guard let path = profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath
        case order
    }
}

/// Crew member from TMDB
struct CrewMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let job: String
    let department: String
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case job
        case department
        case profilePath
    }
}
