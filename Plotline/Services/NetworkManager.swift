import Foundation

/// Network errors for the application
nonisolated enum NetworkError: Error, LocalizedError {
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
            return "Something went wrong. Please try again."
        case .invalidResponse:
            return "Couldn't connect to the server. Please try again."
        case .decodingError:
            return "Something went wrong loading this content."
        case .serverError:
            return "The server is temporarily unavailable. Please try again later."
        case .noData:
            return "No content found."
        case .networkUnavailable:
            return "No internet connection. Check your network and try again."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        }
    }

    /// The URL-loading failures that mean "there is no connection", as opposed
    /// to a server that answered badly. Everything else passes through as-is.
    static func mapping(_ error: URLError) -> Error {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return NetworkError.networkUnavailable
        case .cancelled:
            return CancellationError()
        default:
            return error
        }
    }
}

/// When to try a rate-limited request again, and when to stop.
///
/// A pure value so the decision can be tested without a network: TMDB answers
/// a burst with HTTP 429 and usually a `Retry-After`, and a long-running series
/// fetched season by season is exactly such a burst.
nonisolated struct RetryPolicy: Sendable {
    /// Total attempts, the first one included.
    var maxAttempts: Int = 3
    /// Backoff before the first retry when the server gives no `Retry-After`;
    /// doubled on each further retry.
    var baseDelay: TimeInterval = 1
    /// Upper bound on any single wait, `Retry-After` included. TMDB's window is
    /// ten seconds; waiting longer than that holds a screen hostage for nothing.
    var maxDelay: TimeInterval = 10

    static let `default` = RetryPolicy()

    /// How long to wait before retrying a request that just got a 429, or `nil`
    /// when the attempt budget is spent.
    ///
    /// - Parameters:
    ///   - attempt: 1-based number of the attempt that was rate limited.
    ///   - retryAfter: the raw `Retry-After` header, either delta-seconds or an
    ///     HTTP date. Unparseable values fall back to exponential backoff.
    func delay(afterAttempt attempt: Int, retryAfter: String?, now: Date = Date()) -> TimeInterval? {
        guard attempt < maxAttempts else { return nil }

        if let retryAfter, let serverDelay = Self.parseRetryAfter(retryAfter, now: now) {
            return min(max(serverDelay, 0), maxDelay)
        }

        let backoff = baseDelay * pow(2, Double(attempt - 1))
        return min(backoff, maxDelay)
    }

    static func parseRetryAfter(_ value: String, now: Date) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if let seconds = TimeInterval(trimmed) {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: trimmed) else { return nil }
        return date.timeIntervalSince(now)
    }
}

/// Networking for the whole app.
///
/// Holds no mutable state — the session and decoder are immutable and
/// `Sendable` — so the request methods are `@concurrent nonisolated`: they run
/// on the global executor rather than queueing behind one another on the actor,
/// and JSON decoding never lands on the main thread nor serialises every other
/// request behind it.
actor NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let retryPolicy: RetryPolicy

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        // Fail fast offline. Waiting for connectivity turned an airplane-mode
        // request into a sixty-second spinner before any error could show.
        config.waitsForConnectivity = false
        // Honour the server's own freshness headers. `.returnCacheDataElseLoad`
        // served a cached response of any age, so trending and series status
        // went stale indefinitely and `DiskCache` expiry was defeated from below.
        config.requestCachePolicy = .useProtocolCachePolicy

        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.retryPolicy = .default
    }

    // MARK: - Public Methods

    /// Generic fetch method for any Decodable type.
    ///
    /// - Parameter cachePolicy: pass `.reloadIgnoringLocalCacheData` for
    ///   payloads `DiskCache` already stores with its own expiry, so there is
    ///   one freshness rule for them instead of two stacked ones.
    @concurrent
    nonisolated func fetch<T: Decodable & Sendable>(
        _ type: T.Type,
        from url: URL,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) async throws -> T {
        let data = try await data(from: url, cachePolicy: cachePolicy)

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

    /// Fetch raw data (useful for debugging)
    @concurrent
    nonisolated func fetchData(from url: URL) async throws -> Data {
        try await data(from: url, cachePolicy: .useProtocolCachePolicy)
    }

    // MARK: - Private

    /// One request, retried on HTTP 429 per `retryPolicy`. Cancellation is
    /// never retried: it surfaces as `CancellationError` straight away.
    @concurrent
    private nonisolated func data(from url: URL, cachePolicy: URLRequest.CachePolicy) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy

        var attempt = 1
        while true {
            try Task.checkCancellation()

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch let error as URLError {
                throw NetworkError.mapping(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                guard let delay = retryPolicy.delay(afterAttempt: attempt, retryAfter: retryAfter) else {
                    throw NetworkError.rateLimited
                }
                try await Task.sleep(for: .seconds(delay))
                attempt += 1
                continue
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            return data
        }
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
