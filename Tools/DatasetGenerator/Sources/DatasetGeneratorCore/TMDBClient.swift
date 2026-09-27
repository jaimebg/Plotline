import Foundation

struct TMDBSeriesDetails {
    let id: Int
    let name: String
    let seasonCount: Int
    /// TMDB's series-level status, reduced to the one bit the analysis engine
    /// needs: `true` for a confirmed ending, `false` for a confirmed running
    /// series, `nil` for anything else. Same mapping as the app's
    /// `SeriesStatus`, so the bundle and a live recomputation read one status
    /// the same way. An unknown status is not "still running" — flattening it
    /// to `false` would mark a pilot or a planned series as ongoing.
    let hasEnded: Bool?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    /// Flattened from `/tv/{id}`'s `genres` objects, which is the same set the
    /// list endpoints return as `genre_ids`.
    let genreIds: [Int]
    let firstAirDate: String?
}

enum TMDBClientError: Error {
    case badStatus(Int)
    case missingAPIKey
}

struct TMDBClient {
    private let apiKey: String
    private let session: URLSession
    private let baseURL = "https://api.themoviedb.org/3"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Requests

    func seriesDetails(id: Int) async throws -> TMDBSeriesDetails {
        let data = try await get("/tv/\(id)")
        return try Self.decodeDetails(data)
    }

    /// Fetches every season in sequence. Deliberately serial: this runs once per
    /// release against a couple of hundred series, so staying well under TMDB's
    /// rate limit matters more than wall-clock time.
    func episodes(seriesId: Int, seasonCount: Int) async throws -> [EpisodeMetric] {
        var all: [EpisodeMetric] = []
        guard seasonCount > 0 else { return all }

        for season in 1...seasonCount {
            let data = try await get("/tv/\(seriesId)/season/\(season)")
            all.append(contentsOf: try Self.decodeSeason(data))
            try await Task.sleep(nanoseconds: 120_000_000)
        }
        return all
    }

    private func get(_ path: String) async throws -> Data {
        var components = URLComponents(string: baseURL + path)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "en-US")
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TMDBClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    // MARK: - Decoding

    static func decodeDetails(_ data: Data) throws -> TMDBSeriesDetails {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = try decoder.decode(RawDetails.self, from: data)

        // TMDB returns "" rather than null for a date it does not have, and an
        // empty string would read as a real value downstream.
        let firstAirDate = raw.firstAirDate.flatMap { $0.isEmpty ? nil : $0 }

        return TMDBSeriesDetails(
            id: raw.id,
            name: raw.name,
            seasonCount: raw.numberOfSeasons ?? 0,
            hasEnded: hasEnded(forTMDBStatus: raw.status),
            overview: raw.overview ?? "",
            posterPath: raw.posterPath,
            backdropPath: raw.backdropPath,
            voteAverage: raw.voteAverage ?? 0,
            genreIds: raw.genres?.map(\.id) ?? [],
            firstAirDate: firstAirDate
        )
    }

    /// Statuses that confirm the run is over. Both spellings of "cancelled"
    /// are deliberate — TMDB returns each.
    static let endedStatuses: Set<String> = ["Ended", "Canceled", "Cancelled"]

    /// Statuses that confirm the series is still being made.
    static let runningStatuses: Set<String> = ["Returning Series", "In Production"]

    /// Mirrors the app's `SeriesStatus.hasEnded(forTMDBStatus:)`, which this
    /// package cannot import (it lives outside the four shared files). Keep
    /// the two in step: "Pilot", "Planned", an absent status and anything TMDB
    /// adds later are all unknown.
    static func hasEnded(forTMDBStatus status: String?) -> Bool? {
        guard let status else { return nil }
        if endedStatuses.contains(status) { return true }
        if runningStatuses.contains(status) { return false }
        return nil
    }

    static func decodeSeason(_ data: Data) throws -> [EpisodeMetric] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = try decoder.decode(RawSeason.self, from: data)

        return raw.episodes.map { episode in
            let name = episode.name?.trimmingCharacters(in: .whitespaces) ?? ""
            return EpisodeMetric(
                id: episode.id,
                episodeNumber: episode.episodeNumber,
                seasonNumber: episode.seasonNumber,
                title: name.isEmpty ? "Episode \(episode.episodeNumber)" : name,
                rating: episode.voteAverage,
                voteCount: episode.voteCount,
                airDate: episode.airDate,
                stillPath: episode.stillPath
            )
        }
    }

    private struct RawDetails: Decodable {
        let id: Int
        let name: String
        let numberOfSeasons: Int?
        let status: String?
        let overview: String?
        let posterPath: String?
        let backdropPath: String?
        let voteAverage: Double?
        let genres: [RawGenre]?
        let firstAirDate: String?
    }

    private struct RawGenre: Decodable {
        let id: Int
    }

    private struct RawSeason: Decodable {
        let episodes: [RawEpisode]
    }

    private struct RawEpisode: Decodable {
        let id: Int
        let name: String?
        let episodeNumber: Int
        let seasonNumber: Int
        let airDate: String?
        let stillPath: String?
        let voteAverage: Double
        let voteCount: Int
    }
}
