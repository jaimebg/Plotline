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

    /// How many ids one SPARQL query may name.
    ///
    /// The endpoint enforces a query timeout, and a `VALUES` clause of 200 ids
    /// is far likelier to hit it than one of 24 — the seed list growing was
    /// enough on its own to turn a working query into a failing one. Small
    /// batches keep each query well inside the budget.
    static let maxIdsPerQuery = 50

    /// - Returns: TMDB series id → sorted award names. Titles with no awards are absent.
    func awards(forSeriesIds ids: [Int]) async throws -> [Int: [String]] {
        guard !ids.isEmpty else { return [:] }

        var merged: [Int: [String]] = [:]
        for (index, batch) in Self.batches(of: ids).enumerated() {
            if index > 0 {
                // Same politeness as the TMDB client: this runs once per
                // release, so staying comfortably inside Wikidata's limits
                // matters more than wall-clock time.
                try await Task.sleep(nanoseconds: 250_000_000)
            }
            // Batches never share an id, so a collision is impossible; the
            // union keeps the merge honest rather than relying on that.
            merged.merge(try await awardsBatch(batch)) { existing, new in
                Set(existing).union(new).sorted()
            }
        }
        return merged
    }

    /// Splits `ids` into query-sized batches, preserving order.
    static func batches(of ids: [Int], size: Int = maxIdsPerQuery) -> [[Int]] {
        guard size > 0 else { return ids.isEmpty ? [] : [ids] }
        return stride(from: 0, to: ids.count, by: size).map {
            Array(ids[$0..<min($0 + size, ids.count)])
        }
    }

    private func awardsBatch(_ ids: [Int]) async throws -> [Int: [String]] {
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
            let label = binding.awardLabel.value
            guard !isUnusableLabel(label) else { continue }
            grouped[id, default: []].insert(label)
        }

        // Sorted so regenerating the dataset from unchanged data produces an
        // identical file, which keeps release diffs readable.
        return grouped.mapValues { $0.sorted() }
    }

    /// Labels that are not an award a user would recognise.
    ///
    /// Two kinds leak out of the label service. A bare QID (`Q3403230`) is what
    /// the service returns when an item has no English label at all — it names
    /// nothing to a reader. And Wikidata models "list of awards and nominations
    /// received by X" as an item a show can be linked to, so the index article
    /// arrives looking exactly like an award. Both would ship as an award badge
    /// on a title's page, which is precisely the unsupported claim this project
    /// exists to avoid.
    static func isUnusableLabel(_ label: String) -> Bool {
        if label.count > 1,
           label.hasPrefix("Q"),
           label.dropFirst().allSatisfy({ $0.isASCII && $0.isNumber }) {
            return true
        }
        return label.lowercased().hasPrefix("list of ")
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
