import Foundation
import Testing
@testable import Plotline

@Suite("Network retry policy")
struct NetworkRetryPolicyTests {
    private let policy = RetryPolicy(maxAttempts: 3, baseDelay: 1, maxDelay: 10)
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    @Test("without Retry-After, backoff doubles per attempt")
    func exponentialBackoff() {
        #expect(policy.delay(afterAttempt: 1, retryAfter: nil, now: now) == 1)
        #expect(policy.delay(afterAttempt: 2, retryAfter: nil, now: now) == 2)
    }

    @Test("stops once the attempt budget is spent")
    func givesUp() {
        #expect(policy.delay(afterAttempt: 3, retryAfter: nil, now: now) == nil)
        #expect(policy.delay(afterAttempt: 3, retryAfter: "1", now: now) == nil)
    }

    @Test("honours Retry-After in seconds")
    func retryAfterSeconds() {
        #expect(policy.delay(afterAttempt: 1, retryAfter: "4", now: now) == 4)
        #expect(policy.delay(afterAttempt: 1, retryAfter: " 0 ", now: now) == 0)
    }

    @Test("honours Retry-After as an HTTP date")
    func retryAfterDate() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let header = formatter.string(from: now.addingTimeInterval(3))

        #expect(policy.delay(afterAttempt: 1, retryAfter: header, now: now) == 3)
    }

    @Test("never waits longer than maxDelay, nor a negative time")
    func clamped() {
        #expect(policy.delay(afterAttempt: 1, retryAfter: "600", now: now) == 10)
        #expect(policy.delay(afterAttempt: 1, retryAfter: "-5", now: now) == 0)

        let longBackoff = RetryPolicy(maxAttempts: 10, baseDelay: 1, maxDelay: 10)
        #expect(longBackoff.delay(afterAttempt: 8, retryAfter: nil, now: now) == 10)
    }

    @Test("an unparseable Retry-After falls back to backoff")
    func garbageHeader() {
        #expect(policy.delay(afterAttempt: 2, retryAfter: "soon", now: now) == 2)
    }

    @Test("connectivity failures map to networkUnavailable", arguments: [
        URLError.Code.notConnectedToInternet,
        .networkConnectionLost,
        .dataNotAllowed,
    ])
    func offlineMapping(code: URLError.Code) {
        let mapped = NetworkError.mapping(URLError(code))
        guard case NetworkError.networkUnavailable = mapped else {
            Issue.record("expected networkUnavailable, got \(mapped)")
            return
        }
    }

    @Test("a cancelled request surfaces as cancellation, not as a failure to retry")
    func cancellationMapping() {
        #expect(NetworkError.mapping(URLError(.cancelled)) is CancellationError)
    }

    @Test("other URL errors pass through untouched")
    func otherErrorsPassThrough() {
        let mapped = NetworkError.mapping(URLError(.timedOut))
        #expect((mapped as? URLError)?.code == .timedOut)
    }
}
