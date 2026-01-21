import Foundation

/// Response wrapper for TMDB API list endpoints
struct TMDBResponse: Codable {
    let page: Int
    let results: [MediaItem]
    let totalPages: Int
    let totalResults: Int
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
    let budget: Int?
    let revenue: Int?
    let belongsToCollection: MovieCollection?

    // TV-specific
    let name: String?
    let firstAirDate: String?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?

    // External IDs (from append_to_response)
    let externalIds: ExternalIds?

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
            totalSeasons: numberOfSeasons,
            budget: budget,
            revenue: revenue,
            collectionId: belongsToCollection?.id,
            collectionName: belongsToCollection?.name
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
}

/// Crew member from TMDB
struct CrewMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let job: String
    let department: String
    let profilePath: String?
}

// MARK: - Collection Models

/// Movie collection reference from detail response
struct MovieCollection: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let posterPath: String?
    let backdropPath: String?

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/original\(path)")
    }
}

/// Full collection response from TMDB /collection/{id}
struct TMDBCollectionResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let parts: [CollectionMovie]
}

/// Movie within a collection
struct CollectionMovie: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String?
    let voteAverage: Double
    let voteCount: Int
    let posterPath: String?
    let backdropPath: String?

    /// Year extracted from release date
    var year: String? {
        guard let date = releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    /// Year as integer for sorting
    var yearInt: Int? {
        year.flatMap { Int($0) }
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    /// Formatted rating string
    var formattedRating: String {
        String(format: "%.1f", voteAverage)
    }

    /// Convert to MediaItem for navigation
    func toMediaItem() -> MediaItem {
        MediaItem(
            id: id,
            overview: overview ?? "",
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIds: nil,
            title: title,
            releaseDate: releaseDate,
            name: nil,
            firstAirDate: nil,
            mediaType: .movie
        )
    }
}

// MARK: - Person Credits Models

/// Response for TMDB /person/{id}/movie_credits
struct TMDBPersonCreditsResponse: Codable {
    let id: Int
    let cast: [PersonCastCredit]
    let crew: [PersonCrewCredit]
}

/// Cast credit for a person (movies they acted in)
struct PersonCastCredit: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let character: String?
    let releaseDate: String?
    let voteAverage: Double
    let voteCount: Int
    let posterPath: String?
    let popularity: Double
    let adult: Bool?

    /// Year extracted from release date
    var year: String? {
        guard let date = releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    /// Formatted rating string
    var formattedRating: String {
        String(format: "%.1f", voteAverage)
    }

    /// Convert to MediaItem for navigation
    func toMediaItem() -> MediaItem {
        MediaItem(
            id: id,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIds: nil,
            title: title,
            releaseDate: releaseDate,
            name: nil,
            firstAirDate: nil,
            mediaType: .movie
        )
    }
}

/// Crew credit for a person (movies they worked on)
struct PersonCrewCredit: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let job: String?
    let department: String?
    let releaseDate: String?
    let voteAverage: Double
    let voteCount: Int
    let posterPath: String?
    let popularity: Double
    let adult: Bool?

    /// Year extracted from release date
    var year: String? {
        guard let date = releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    /// Formatted rating string
    var formattedRating: String {
        String(format: "%.1f", voteAverage)
    }

    /// Check if this is a director credit
    var isDirector: Bool {
        job?.lowercased() == "director"
    }

    /// Convert to MediaItem for navigation
    func toMediaItem() -> MediaItem {
        MediaItem(
            id: id,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIds: nil,
            title: title,
            releaseDate: releaseDate,
            name: nil,
            firstAirDate: nil,
            mediaType: .movie
        )
    }
}
