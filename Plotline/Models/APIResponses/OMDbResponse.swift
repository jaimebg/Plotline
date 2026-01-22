import Foundation

/// Response from OMDb API for movie/series info
struct OMDbResponse: Codable {
    let title: String?
    let year: String?
    let rated: String?
    let released: String?
    let runtime: String?
    let genre: String?
    let director: String?
    let writer: String?
    let actors: String?
    let plot: String?
    let language: String?
    let country: String?
    let awards: String?
    let poster: String?
    let ratings: [RatingSource]?
    let metascore: String?
    let imdbRating: String?
    let imdbVotes: String?
    let imdbID: String?
    let type: String?
    let totalSeasons: String?
    let response: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case year = "Year"
        case rated = "Rated"
        case released = "Released"
        case runtime = "Runtime"
        case genre = "Genre"
        case director = "Director"
        case writer = "Writer"
        case actors = "Actors"
        case plot = "Plot"
        case language = "Language"
        case country = "Country"
        case awards = "Awards"
        case poster = "Poster"
        case ratings = "Ratings"
        case metascore = "Metascore"
        case imdbRating
        case imdbVotes
        case imdbID
        case type = "Type"
        case totalSeasons
        case response = "Response"
        case error = "Error"
    }

    /// Check if response is valid
    var isSuccess: Bool {
        response?.lowercased() == "true"
    }

    /// Total seasons as Int
    var totalSeasonsInt: Int? {
        guard let str = totalSeasons else { return nil }
        return Int(str)
    }
}

/// Response from OMDb API for season episodes
struct OMDbSeasonResponse: Codable {
    let title: String?
    let season: String?
    let totalSeasons: String?
    let episodes: [OMDbEpisode]?
    let response: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case season = "Season"
        case totalSeasons
        case episodes = "Episodes"
        case response = "Response"
        case error = "Error"
    }

    /// Check if response is valid
    var isSuccess: Bool {
        response?.lowercased() == "true"
    }

    /// Season number as Int
    var seasonNumber: Int? {
        guard let str = season else { return nil }
        return Int(str)
    }

    /// Convert episodes to EpisodeMetric array
    /// Note: Returns ALL episodes including those with N/A ratings.
    /// Views should filter for valid ratings when needed (e.g., charts).
    func toEpisodeMetrics() -> [EpisodeMetric] {
        guard let episodes, let seasonNum = seasonNumber else { return [] }

        return episodes.compactMap { episode in
            guard let episodeNumber = Int(episode.episode) else { return nil }
            return EpisodeMetric(
                episodeNumber: episodeNumber,
                seasonNumber: seasonNum,
                title: episode.title,
                imdbRating: episode.imdbRating,
                imdbId: episode.imdbID
            )
        }
    }
}

/// Episode data from OMDb API
struct OMDbEpisode: Codable {
    let title: String
    let released: String
    let episode: String
    let imdbRating: String
    let imdbID: String

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case released = "Released"
        case episode = "Episode"
        case imdbRating
        case imdbID
    }
}
