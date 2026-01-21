import Foundation

/// Service for interacting with the Open Movie Database (OMDb) API
/// Provides ratings from IMDb, Rotten Tomatoes, and Metacritic
struct OMDbService {
    static let shared = OMDbService()

    private let baseURL = "https://www.omdbapi.com"
    private let apiKey = Secrets.omdbAPIKey
    private let networkManager = NetworkManager.shared

    // Cache for OMDb responses to avoid repeated API calls
    private let cache = OMDbCache.shared

    private init() {}

    // MARK: - Public Methods

    /// Fetch ratings for a movie or TV series by IMDb ID
    func fetchRatings(imdbId: String) async throws -> [RatingSource] {
        // Check cache first
        if let cached = await cache.getRatings(for: imdbId) {
            return cached
        }

        guard let url = buildURL(params: ["i": imdbId]) else {
            throw NetworkError.invalidURL
        }

        let response: OMDbResponse = try await networkManager.fetch(
            OMDbResponse.self,
            from: url,
            decoder: omdbDecoder
        )

        guard response.isSuccess else {
            throw OMDbError.apiError(response.error ?? "Unknown error")
        }

        let ratings = response.ratings ?? []

        // Cache the result
        await cache.setRatings(ratings, for: imdbId)

        return ratings
    }

    /// Fetch full OMDb details (includes ratings, plot, etc.)
    func fetchDetails(imdbId: String) async throws -> OMDbResponse {
        guard let url = buildURL(params: ["i": imdbId, "plot": "full"]) else {
            throw NetworkError.invalidURL
        }

        let response: OMDbResponse = try await networkManager.fetch(
            OMDbResponse.self,
            from: url,
            decoder: omdbDecoder
        )

        guard response.isSuccess else {
            throw OMDbError.apiError(response.error ?? "Unknown error")
        }

        return response
    }

    /// Fetch episode ratings for a specific season
    func fetchSeasonEpisodes(imdbId: String, season: Int) async throws -> [EpisodeMetric] {
        // Check cache first
        let cacheKey = "\(imdbId)_S\(season)"
        if let cached = await cache.getEpisodes(for: cacheKey) {
            return cached
        }

        guard let url = buildURL(params: ["i": imdbId, "Season": "\(season)"]) else {
            throw NetworkError.invalidURL
        }

        let response: OMDbSeasonResponse = try await networkManager.fetch(
            OMDbSeasonResponse.self,
            from: url,
            decoder: omdbDecoder
        )

        guard response.isSuccess else {
            throw OMDbError.apiError(response.error ?? "Unknown error")
        }

        let episodes = response.toEpisodeMetrics()

        // Cache the result
        await cache.setEpisodes(episodes, for: cacheKey)

        return episodes
    }

    /// Fetch all seasons' episodes for a series
    func fetchAllSeasons(imdbId: String, totalSeasons: Int) async throws -> [[EpisodeMetric]] {
        var allEpisodes: [[EpisodeMetric]] = []

        for season in 1...totalSeasons {
            do {
                let episodes = try await fetchSeasonEpisodes(imdbId: imdbId, season: season)
                allEpisodes.append(episodes)
            } catch {
                // If a season fails, add empty array but continue
                #if DEBUG
                print("Failed to fetch season \(season): \(error)")
                #endif
                allEpisodes.append([])
            }
        }

        return allEpisodes
    }

    // MARK: - Private Helpers

    private func buildURL(params: [String: String]) -> URL? {
        guard var components = URLComponents(string: baseURL) else {
            return nil
        }

        var queryItems = [URLQueryItem(name: "apikey", value: apiKey)]

        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }

        components.queryItems = queryItems
        return components.url
    }

    /// Custom decoder for OMDb (uses PascalCase keys)
    private var omdbDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        // OMDb uses PascalCase, handled in CodingKeys
        return decoder
    }
}

// MARK: - OMDb Errors

enum OMDbError: Error, LocalizedError {
    case apiError(String)
    case noRatings
    case invalidIMDbId

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "OMDb API Error: \(message)"
        case .noRatings:
            return "No ratings available"
        case .invalidIMDbId:
            return "Invalid IMDb ID"
        }
    }
}

// MARK: - OMDb Cache

/// Actor-based cache for OMDb responses
actor OMDbCache {
    static let shared = OMDbCache()

    private var ratingsCache: [String: [RatingSource]] = [:]
    private var episodesCache: [String: [EpisodeMetric]] = [:]
    private var detailsCache: [String: OMDbResponse] = [:]

    private init() {}

    // MARK: - Ratings

    func getRatings(for imdbId: String) -> [RatingSource]? {
        ratingsCache[imdbId]
    }

    func setRatings(_ ratings: [RatingSource], for imdbId: String) {
        ratingsCache[imdbId] = ratings
    }

    // MARK: - Episodes

    func getEpisodes(for key: String) -> [EpisodeMetric]? {
        episodesCache[key]
    }

    func setEpisodes(_ episodes: [EpisodeMetric], for key: String) {
        episodesCache[key] = episodes
    }

    // MARK: - Details

    func getDetails(for imdbId: String) -> OMDbResponse? {
        detailsCache[imdbId]
    }

    func setDetails(_ details: OMDbResponse, for imdbId: String) {
        detailsCache[imdbId] = details
    }

    // MARK: - Clear

    func clearAll() {
        ratingsCache.removeAll()
        episodesCache.removeAll()
        detailsCache.removeAll()
    }
}
