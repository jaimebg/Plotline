import Foundation
import Testing
@testable import DatasetGeneratorCore

/// The guard around the one string that used to be `"\(error)"`.
///
/// A `URLSession` error carries the failing URL in `userInfo`, the TMDB request
/// URL carries `api_key=…`, and the skip record that string landed in is
/// committed to git *and* copied into the shipped app bundle. One transient
/// failure during a regeneration was enough — the outage guard only trips past
/// 50% failure, so it would never have caught it.
@Suite("Fetch failure detail")
struct FetchFailureTests {
    /// Exactly the error `URLSession` hands back on a failed request, complete
    /// with the key-bearing URL that used to be interpolated.
    private let secretURL = URL(string: "https://api.themoviedb.org/3/tv/1396?api_key=s3cr3t&language=en-US")!

    private var sessionStyleError: Error {
        URLError(.timedOut, userInfo: [
            NSURLErrorFailingURLErrorKey: secretURL,
            NSURLErrorFailingURLStringErrorKey: secretURL.absoluteString,
            NSLocalizedDescriptionKey: "The request timed out."
        ])
    }

    @Test("a URLSession error never yields its URL, its key or its description")
    func urlErrorLeaksNothing() throws {
        let detail = try #require(FetchFailure.detail(for: sessionStyleError))

        #expect(!detail.contains("s3cr3t"))
        #expect(!detail.contains("api_key"))
        #expect(!detail.contains("themoviedb"))
        #expect(!detail.contains("://"))
        #expect(detail == "URLError \(URLError.Code.timedOut.rawValue)")
    }

    @Test("interpolating the same error directly would have leaked the key")
    func theOldBehaviourReallyDidLeak() {
        // Pins the reason the fix exists. If this ever stops holding, the
        // hazard is gone and the guard can be revisited — until then it is
        // proof that `"\(error)"` was one blip away from committing a secret.
        #expect("\(sessionStyleError)".contains("s3cr3t"))
    }

    @Test("an HTTP failure keeps its status code and nothing else")
    func httpStatusSurvives() {
        #expect(FetchFailure.detail(for: TMDBClientError.badStatus(429)) == "HTTP 429")
        #expect(FetchFailure.detail(for: WikidataError.badStatus(500)) == "HTTP 500")
    }

    @Test("a decoding failure reduces to a category, never to its context")
    func decodingFailureIsACategory() {
        struct Key: CodingKey {
            var stringValue = "name"
            var intValue: Int?
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
            init() {}
        }

        let error = DecodingError.keyNotFound(
            Key(),
            .init(codingPath: [], debugDescription: "https://api.themoviedb.org/3?api_key=s3cr3t")
        )
        #expect(FetchFailure.detail(for: error) == "decodingFailed")
    }

    @Test("an unrecognised error yields no detail at all rather than a best effort")
    func unknownErrorsYieldNil() {
        struct Mystery: Error { let url = "https://api.themoviedb.org/3?api_key=s3cr3t" }
        #expect(FetchFailure.detail(for: Mystery()) == nil)
    }
}
