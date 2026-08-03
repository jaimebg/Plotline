import Foundation

enum WikidataError: Error {
    case badStatus(Int)
}

/// Fetches awards from Wikidata's SPARQL endpoint.
///
/// Wikidata is queried **by TMDB id**, never by award identifier. An earlier
/// attempt that enumerated award QIDs returned nothing because the guessed QID
/// was wrong — and guessing was never necessary, since the generator already
/// starts from a list of TMDB ids. Asking "what did this show win?" is both
/// correct and simpler than asking "who won this award?".
struct WikidataClient {
    private let session: URLSession
    private let endpoint = "https://query.wikidata.org/sparql"

    /// Wikidata rejects anonymous traffic with 403. A contactable agent string
    /// is a hard requirement, not politeness.
    private let userAgent = "PlotlineDatasetGenerator/1.0 (https://github.com/jaimebg/Plotline)"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// - Returns: TMDB series id → sorted award names. Titles with no awards are absent.
    func awards(forSeriesIds ids: [Int]) async throws -> [Int: [String]] {
        guard !ids.isEmpty else { return [:] }

        var components = URLComponents(string: endpoint)!
        components.queryItems = [URLQueryItem(name: "query", value: Self.awardsQuery(forSeriesIds: ids))]

        var request = URLRequest(url: components.url!)
        request.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WikidataError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try Self.decodeAwards(data)
    }

    static func awardsQuery(forSeriesIds ids: [Int]) -> String {
        let values = ids.map { "\"\($0)\"" }.joined(separator: " ")
        return """
        SELECT ?tmdbId ?awardLabel WHERE {
          VALUES ?tmdbId { \(values) }
          ?show wdt:P4983 ?tmdbId .
          ?show wdt:P166 ?award .
          SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        }
        """
    }

    static func decodeAwards(_ data: Data) throws -> [Int: [String]] {
        let response = try JSONDecoder().decode(SPARQLResponse.self, from: data)

        var grouped: [Int: Set<String>] = [:]
        for binding in response.results.bindings {
            guard let id = Int(binding.tmdbId.value) else { continue }
            grouped[id, default: []].insert(binding.awardLabel.value)
        }

        // Sorted so regenerating the dataset from unchanged data produces an
        // identical file, which keeps release diffs readable.
        return grouped.mapValues { $0.sorted() }
    }

    private struct SPARQLResponse: Decodable {
        let results: Results

        struct Results: Decodable {
            let bindings: [Binding]
        }

        struct Binding: Decodable {
            let tmdbId: Value
            let awardLabel: Value
        }

        struct Value: Decodable {
            let value: String
        }
    }
}
