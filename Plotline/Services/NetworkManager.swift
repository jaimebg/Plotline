import Foundation

/// Network errors for the application
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case serverError(Int)
    case noData
    case networkUnavailable
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .noData:
            return "No data received"
        case .networkUnavailable:
            return "Network unavailable"
        case .rateLimited:
            return "Rate limited. Please try again later."
        }
    }
}

/// Thread-safe network manager using Swift Actor
actor NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad

        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Public Methods

    /// Generic fetch method for any Decodable type
    func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            throw NetworkError.rateLimited
        }

        // Handle other errors
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("Decoding error for \(T.self): \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString.prefix(500))")
            }
            #endif
            throw NetworkError.decodingError(error)
        }
    }

    /// Fetch with custom decoder (for APIs with different key strategies)
    func fetch<T: Decodable>(_ type: T.Type, from url: URL, decoder customDecoder: JSONDecoder) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw NetworkError.rateLimited
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        do {
            return try customDecoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("Decoding error for \(T.self): \(error)")
            #endif
            throw NetworkError.decodingError(error)
        }
    }

    /// Fetch raw data (useful for debugging)
    func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - URL Builder

extension URL {
    /// Adds query parameters to a URL
    func appending(queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }

        var existingItems = components.queryItems ?? []
        existingItems.append(contentsOf: queryItems)
        components.queryItems = existingItems

        return components.url
    }
}
