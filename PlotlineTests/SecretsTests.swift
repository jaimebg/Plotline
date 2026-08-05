import Foundation
import Testing
@testable import Plotline

/// The resolution order is not a preference: it is the mechanism the starved
/// UI pass depends on. Launching the app with `TMDB_API_KEY=""` has to leave
/// it with no key, and that only works if an explicitly set environment
/// variable beats the plist committed into the bundle.
@Suite("Secrets resolution")
struct SecretsTests {
    @Test("an environment variable beats the bundled plist")
    func environmentWins() {
        let value = Secrets.resolve(
            "TMDB_API_KEY",
            environment: ["TMDB_API_KEY": "from-env"],
            plist: ["TMDB_API_KEY": "from-plist"]
        )
        #expect(value == "from-env")
    }

    /// The one case the UI test rides on. If an empty value fell through to
    /// the plist, the starved pass would silently run against live TMDB and
    /// assert nothing at all about the bundled dataset — green, and covering
    /// nothing.
    @Test("an empty environment value means no key, not fall through")
    func emptyEnvironmentValueStillWins() {
        let value = Secrets.resolve(
            "TMDB_API_KEY",
            environment: ["TMDB_API_KEY": ""],
            plist: ["TMDB_API_KEY": "from-plist"]
        )
        #expect(value == "")
    }

    @Test("the plist is used when the environment says nothing")
    func plistIsTheFallback() {
        let value = Secrets.resolve(
            "TMDB_API_KEY",
            environment: [:],
            plist: ["TMDB_API_KEY": "from-plist"]
        )
        #expect(value == "from-plist")
    }

    @Test("an unknown key resolves to an empty string, never nil")
    func unknownKeyIsEmpty() {
        #expect(Secrets.resolve("NOPE", environment: [:], plist: [:]) == "")
    }
}
