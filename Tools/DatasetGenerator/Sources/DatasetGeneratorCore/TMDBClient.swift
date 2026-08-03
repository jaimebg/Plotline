import Foundation

struct TMDBSeriesDetails {
    let id: Int
    let name: String
    let seasonCount: Int
    /// TMDB's series-level status, reduced to the one bit the analysis engine
    /// needs. Anything other than a terminal status counts as not ended, so an
    /// ending verdict is never claimed about a show still in production.
    let hasEnded: Bool
    let posterPath: String?
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

        // TMDB uses "Ended" and "Canceled" for finished runs; everything else
        // ("Returning Series", "In Production", "Planned") means still going.
        let terminal: Set<String> = ["Ended", "Canceled", "Cancelled"]

        return TMDBSeriesDetails(
            id: raw.id,
            name: raw.name,
            seasonCount: raw.numberOfSeasons ?? 0,
            hasEnded: terminal.contains(raw.status ?? ""),
            posterPath: raw.posterPath
        )
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
        let posterPath: String?
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
