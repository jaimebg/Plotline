import Foundation

/// Service for interacting with the Open Movie Database (OMDb) API
/// Provides ratings from IMDb, Rotten Tomatoes, and Metacritic
struct OMDbService {
    static let shared = OMDbService()

    private let baseURL = "https://www.omdbapi.com"
    private let apiKey = Secrets.omdbAPIKey
    private let networkManager = NetworkManager.shared

    // Cache for OMDb responses to avoid repeated API calls
    private let cache = DiskCache.shared

    // Cache version - increment when data format changes to invalidate old cache
    private let cacheVersion = "v2"

    private init() {}

    // MARK: - Public Methods

    /// Fetch ratings for a movie or TV series by IMDb ID
    func fetchRatings(imdbId: String) async throws -> [RatingSource] {
        let cacheKey = "\(cacheVersion)_ratings_\(imdbId)"
        if let cached: [RatingSource] = await cache.get(for: cacheKey) {
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

        await cache.set(ratings, for: cacheKey)

        return ratings
    }

    /// Fetch full OMDb details (includes ratings, plot, etc.)
    func fetchDetails(imdbId: String) async throws -> OMDbResponse {
        let cacheKey = "\(cacheVersion)_details_\(imdbId)"
        if let cached: OMDbResponse = await cache.get(for: cacheKey) {
            return cached
        }

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

        await cache.set(response, for: cacheKey)

        return response
    }

    /// Fetch episode ratings for a specific season
    func fetchSeasonEpisodes(imdbId: String, season: Int) async throws -> [EpisodeMetric] {
        // Check cache first (versioned key invalidates old data)
        let cacheKey = "\(cacheVersion)_\(imdbId)_S\(season)"
        if let cached: [EpisodeMetric] = await cache.get(for: cacheKey) {
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

        #if DEBUG
        // Log episode count (OMDb API limits to 100 episodes per season)
        if episodes.count >= 100 {
            print("⚠️ OMDb S\(season): Hit 100 episode limit - show may have more episodes")
        }
        // Log episodes with invalid ratings for debugging
        let invalidEpisodes = episodes.filter { !$0.hasValidRating }
        if !invalidEpisodes.isEmpty {
            print("⚠️ OMDb S\(season): \(invalidEpisodes.count) episodes with invalid ratings")
        }
        print("✅ OMDb S\(season): \(episodes.count) total, \(episodes.filter { $0.hasValidRating }.count) valid")
        #endif

        await cache.set(episodes, for: cacheKey)

        return episodes
    }

    /// Fetch all seasons' episodes for a series, returning an empty array for any season that fails
    func fetchAllSeasons(imdbId: String, totalSeasons: Int) async -> [[EpisodeMetric]] {
        var allEpisodes: [[EpisodeMetric]] = []

        for season in 1...totalSeasons {
            let episodes = (try? await fetchSeasonEpisodes(imdbId: imdbId, season: season)) ?? []
            allEpisodes.append(episodes)
        }

        return allEpisodes
    }

    // MARK: - Private Helpers

    private func buildURL(params: [String: String]) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [URLQueryItem(name: "apikey", value: apiKey)]
            + params.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components?.url
    }

    /// OMDb uses PascalCase keys, handled via explicit CodingKeys in models
    private let omdbDecoder = JSONDecoder()
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
