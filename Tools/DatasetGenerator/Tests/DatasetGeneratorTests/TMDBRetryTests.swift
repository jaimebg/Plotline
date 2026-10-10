import Foundation
import Testing
@testable import DatasetGeneratorCore

/// Serves canned HTTP replies in order, so retry behaviour is tested without
/// the network. Static state, hence the serialized suite.
final class StubURLProtocol: URLProtocol {
    struct Reply {
        let status: Int
        var headers: [String: String] = [:]
        var body = Data()
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies: [Reply] = []
    nonisolated(unsafe) private static var count = 0

    static func serve(_ new: [Reply]) {
        lock.lock(); replies = new; count = 0; lock.unlock()
    }

    static var requestCount: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        let reply = Self.replies.isEmpty ? Reply(status: 500) : Self.replies.removeFirst()
        Self.lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double] = []

    func record(_ seconds: Double) {
        lock.lock(); values.append(seconds); lock.unlock()
    }

    var delays: [Double] {
        lock.lock(); defer { lock.unlock() }
        return values
    }
}

@Suite("TMDB retry", .serialized)
struct TMDBRetryTests {
    private let details = Data(#"{"id": 1, "name": "X", "number_of_seasons": 2, "status": "Ended"}"#.utf8)

    private func client(_ recorder: SleepRecorder) -> TMDBClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return TMDBClient(
            apiKey: "test-key",
            session: URLSession(configuration: configuration),
            sleep: { recorder.record($0) }
        )
    }

    @Test("the delay policy", arguments: [
        (429, nil as String?, 1, 2.0 as Double?),
        (429, "3", 1, 3.0),
        (429, "120", 1, 60.0),
        (429, "-1", 1, 2.0),
        (429, "Wed, 21 Oct 2015 07:28:00 GMT", 1, 2.0),
        (503, nil, 2, 4.0),
        (500, nil, 3, nil),
        (404, nil, 1, nil),
        (200, nil, 1, nil),
    ])
    func delayPolicy(status: Int, retryAfter: String?, attempt: Int, expected: Double?) {
        #expect(TMDBClient.retryDelay(status: status, retryAfter: retryAfter, attempt: attempt) == expected)
    }

    @Test("a 429 is retried after the Retry-After it carries")
    func retriesRateLimit() async throws {
        let recorder = SleepRecorder()
        StubURLProtocol.serve([.init(status: 429, headers: ["Retry-After": "3"]), .init(status: 200, body: details)])

        let fetched = try await client(recorder).seriesDetails(id: 1)

        #expect(fetched.name == "X")
        #expect(StubURLProtocol.requestCount == 2)
        #expect(recorder.delays == [3])
    }

    @Test("server errors back off 2 s then 4 s")
    func backsOffOnServerErrors() async throws {
        let recorder = SleepRecorder()
        StubURLProtocol.serve([.init(status: 503), .init(status: 502), .init(status: 200, body: details)])

        _ = try await client(recorder).seriesDetails(id: 1)

        #expect(StubURLProtocol.requestCount == 3)
        #expect(recorder.delays == [2, 4])
    }

    @Test("gives up after three attempts, and the failure carries no URL or key")
    func givesUp() async {
        let recorder = SleepRecorder()
        StubURLProtocol.serve([.init(status: 503), .init(status: 503), .init(status: 503)])

        do {
            _ = try await client(recorder).seriesDetails(id: 1)
            Issue.record("expected the third 503 to throw")
        } catch {
            let detail = FetchFailure.detail(for: error)
            #expect(detail == "HTTP 503")
            #expect(!(detail ?? "").contains("test-key"))
        }
        #expect(StubURLProtocol.requestCount == 3)
        #expect(recorder.delays == [2, 4])
    }

    @Test("a client error is not retried")
    func doesNotRetryNotFound() async {
        let recorder = SleepRecorder()
        StubURLProtocol.serve([.init(status: 404)])

        do {
            _ = try await client(recorder).seriesDetails(id: 1)
            Issue.record("expected a 404 to throw")
        } catch {
            #expect(FetchFailure.detail(for: error) == "HTTP 404")
        }
        #expect(StubURLProtocol.requestCount == 1)
        #expect(recorder.delays.isEmpty)
    }
}
