import Foundation

/// Service for interacting with The Movie Database (TMDB) API
struct TMDBService {
    static let shared = TMDBService()

    private let baseURL = "https://api.themoviedb.org/3"

    private let apiKey = Secrets.tmdbAPIKey

    private let networkManager = NetworkManager.shared

    private init() {}

    // MARK: - Trending

    /// Fetch trending movies for the week
    func fetchTrendingMovies() async throws -> [MediaItem] {
        guard let url = buildURL(path: "/trending/movie/week") else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)
        return response.results
    }

    /// Fetch trending TV series for the week
    func fetchTrendingSeries() async throws -> [MediaItem] {
        guard let url = buildURL(path: "/trending/tv/week") else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)
        return response.results
    }

    /// Fetch all trending content (movies + TV)
    func fetchTrendingAll() async throws -> [MediaItem] {
        guard let url = buildURL(path: "/trending/all/week") else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)
        return response.results
    }

    // MARK: - Popular

    /// Fetch popular movies
    func fetchPopularMovies(page: Int = 1) async throws -> [MediaItem] {
        guard let url = buildURL(path: "/movie/popular", additionalParams: ["page": "\(page)"]) else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)
        return response.results
    }

    /// Fetch popular TV series
    func fetchPopularSeries(page: Int = 1) async throws -> [MediaItem] {
        guard let url = buildURL(path: "/tv/popular", additionalParams: ["page": "\(page)"]) else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)
        return response.results
    }

    // MARK: - Top Rated

    /// Fetch top rated movies
    func fetchTopRatedMovies(page: Int = 1) async throws -> [MediaItem] {
        guard let url = buildURL(path: "/movie/top_rated", additionalParams: ["page": "\(page)"]) else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)
        return response.results
    }

    /// Fetch top rated TV series
    func fetchTopRatedSeries(page: Int = 1) async throws -> [MediaItem] {
        guard let url = buildURL(path: "/tv/top_rated", additionalParams: ["page": "\(page)"]) else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)
        return response.results
    }

    // MARK: - Details

    /// Fetch movie details with external IDs (for IMDb linking)
    func fetchMovieDetails(id: Int) async throws -> MediaItem {
        guard let url = buildURL(
            path: "/movie/\(id)",
            additionalParams: ["append_to_response": "external_ids"]
        ) else {
            throw NetworkError.invalidURL
        }

        let response: TMDBDetailResponse = try await networkManager.fetch(TMDBDetailResponse.self, from: url)
        return response.toMediaItem(mediaType: .movie)
    }

    /// Fetch TV series details with external IDs
    func fetchSeriesDetails(id: Int) async throws -> MediaItem {
        guard let url = buildURL(
            path: "/tv/\(id)",
            additionalParams: ["append_to_response": "external_ids"]
        ) else {
            throw NetworkError.invalidURL
        }

        let response: TMDBDetailResponse = try await networkManager.fetch(TMDBDetailResponse.self, from: url)
        return response.toMediaItem(mediaType: .tv)
    }

    /// Fetch details for any media type
    func fetchDetails(for item: MediaItem) async throws -> MediaItem {
        if item.isTVSeries {
            return try await fetchSeriesDetails(id: item.id)
        } else {
            return try await fetchMovieDetails(id: item.id)
        }
    }

    // MARK: - Search

    /// Search for movies, TV shows, and people
    func searchMulti(query: String, page: Int = 1) async throws -> [MediaItem] {
        guard !query.isEmpty else { return [] }

        // Don't pre-encode query - URLQueryItem handles encoding automatically
        guard let url = buildURL(
            path: "/search/multi",
            additionalParams: ["query": query, "page": "\(page)"]
        ) else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)

        // Filter to only movies and TV shows with posters
        return response.results.filter { item in
            (item.mediaType == .movie || item.mediaType == .tv) && item.posterPath != nil
        }
    }

    /// Search only movies
    func searchMovies(query: String, page: Int = 1) async throws -> [MediaItem] {
        guard !query.isEmpty else { return [] }

        // Don't pre-encode query - URLQueryItem handles encoding automatically
        guard let url = buildURL(
            path: "/search/movie",
            additionalParams: ["query": query, "page": "\(page)"]
        ) else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)
        // Filter out items without posters
        return response.results.filter { $0.posterPath != nil }
    }

    /// Search only TV series
    func searchSeries(query: String, page: Int = 1) async throws -> [MediaItem] {
        guard !query.isEmpty else { return [] }

        // Don't pre-encode query - URLQueryItem handles encoding automatically
        guard let url = buildURL(
            path: "/search/tv",
            additionalParams: ["query": query, "page": "\(page)"]
        ) else {
            throw NetworkError.invalidURL
        }

        let response: TMDBResponse = try await networkManager.fetch(TMDBResponse.self, from: url)
        // Filter out items without posters
        return response.results.filter { $0.posterPath != nil }
    }

    // MARK: - Credits

    /// Fetch cast and crew for a movie
    func fetchMovieCredits(id: Int) async throws -> TMDBCreditsResponse {
        guard let url = buildURL(path: "/movie/\(id)/credits") else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.fetch(TMDBCreditsResponse.self, from: url)
    }

    /// Fetch cast and crew for a TV series
    func fetchSeriesCredits(id: Int) async throws -> TMDBCreditsResponse {
        guard let url = buildURL(path: "/tv/\(id)/credits") else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.fetch(TMDBCreditsResponse.self, from: url)
    }

    // MARK: - Collections

    /// Fetch collection details (franchise movies)
    func fetchCollection(id: Int) async throws -> TMDBCollectionResponse {
        guard let url = buildURL(path: "/collection/\(id)") else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.fetch(TMDBCollectionResponse.self, from: url)
    }

    // MARK: - Person Credits

    /// Fetch movie credits for a person (filmography)
    func fetchPersonMovieCredits(personId: Int) async throws -> TMDBPersonCreditsResponse {
        guard let url = buildURL(path: "/person/\(personId)/movie_credits") else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.fetch(TMDBPersonCreditsResponse.self, from: url)
    }

    // MARK: - Private Helpers

    private func buildURL(path: String, additionalParams: [String: String] = [:]) -> URL? {
        guard var components = URLComponents(string: baseURL + path) else {
            return nil
        }

        var queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "en-US")
        ]

        for (key, value) in additionalParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }

        components.queryItems = queryItems
        return components.url
    }
}

// MARK: - Image URL Helpers

extension TMDBService {
    enum PosterSize: String {
        case small = "w185"
        case medium = "w342"
        case large = "w500"
        case xLarge = "w780"
    }

    enum BackdropSize: String {
        case small = "w300"
        case medium = "w780"
        case large = "w1280"
        case original = "original"
    }

    enum ProfileSize: String {
        case small = "w45"
        case medium = "w185"
        case large = "h632"
    }

    static let imageBaseURL = "https://image.tmdb.org/t/p/"

    static func posterURL(path: String?, size: PosterSize = .large) -> URL? {
        guard let path = path else { return nil }
        return URL(string: imageBaseURL + size.rawValue + path)
    }

    static func backdropURL(path: String?, size: BackdropSize = .original) -> URL? {
        guard let path = path else { return nil }
        return URL(string: imageBaseURL + size.rawValue + path)
    }

    static func profileURL(path: String?, size: ProfileSize = .medium) -> URL? {
        guard let path = path else { return nil }
        return URL(string: imageBaseURL + size.rawValue + path)
    }
}
