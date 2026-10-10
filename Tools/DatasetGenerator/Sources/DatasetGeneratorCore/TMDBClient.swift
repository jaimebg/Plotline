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
    typealias Sleep = @Sendable (_ seconds: Double) async throws -> Void

    /// One first try and two retries. Enough to ride out a rate-limit window
    /// or a brief 5xx, few enough that a dead endpoint fails the run quickly.
    static let maxAttempts = 3

    private let apiKey: String
    private let session: URLSession
    private let sleep: Sleep
    private let baseURL = "https://api.themoviedb.org/3"

    init(
        apiKey: String,
        session: URLSession = .shared,
        sleep: @escaping Sleep = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }
    ) {
        self.apiKey = apiKey
        self.session = session
        self.sleep = sleep
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

    /// How long to wait before attempt `attempt + 1`, or nil to stop.
    ///
    /// Only 429 and 5xx are worth another try. At ~8,000 requests a run, a
    /// single unretried blip used to drop a series into `skipped` as a fetch
    /// failure — silently thinning the dataset. `Retry-After` is honoured when
    /// it is a number of seconds (capped, so a hostile header cannot stall the
    /// run); an HTTP-date or junk falls back to 2 s, then 4 s.
    static func retryDelay(status: Int, retryAfter: String?, attempt: Int) -> Double? {
        guard attempt < maxAttempts else { return nil }
        guard status == 429 || (500...599).contains(status) else { return nil }

        if let retryAfter,
           let seconds = Double(retryAfter.trimmingCharacters(in: .whitespaces)),
           seconds >= 0 {
            return min(seconds, 60)
        }
        return pow(2, Double(attempt))
    }

    private func get(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(string: baseURL + path)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "en-US")
        ] + query
        let url = components.url!

        var attempt = 1
        while true {
            let (data, response) = try await session.data(from: url)
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? -1
            if (200...299).contains(status) { return data }

            // Only the status code leaves this scope — see `FetchFailure`.
            guard let delay = Self.retryDelay(
                status: status,
                retryAfter: http?.value(forHTTPHeaderField: "Retry-After"),
                attempt: attempt
            ) else {
                throw TMDBClientError.badStatus(status)
            }
            try await sleep(delay)
            attempt += 1
        }
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
