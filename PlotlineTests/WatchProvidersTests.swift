import Foundation
import Testing
@testable import Plotline

@Suite("Watch providers")
struct WatchProvidersTests {
    /// Trimmed from the real response for Breaking Bad. Spain carries only
    /// `link` and `flatrate`; the United States adds `buy`. That asymmetry is
    /// the point — every category is genuinely optional.
    private let json = Data("""
    {
      "id": 1396,
      "results": {
        "ES": {
          "link": "https://www.themoviedb.org/tv/1396/watch?locale=ES",
          "flatrate": [
            {"logo_path": "/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg", "provider_id": 8, "provider_name": "Netflix", "display_priority": 0}
          ]
        },
        "US": {
          "link": "https://www.themoviedb.org/tv/1396/watch?locale=US",
          "flatrate": [
            {"logo_path": "/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg", "provider_id": 8, "provider_name": "Netflix", "display_priority": 0}
          ],
          "buy": [
            {"logo_path": "/seGSXajazLMCKGB5hnRCidtjay1.jpg", "provider_id": 2, "provider_name": "Apple TV", "display_priority": 3}
          ]
        }
      }
    }
    """.utf8)

    private func decoded() throws -> WatchProvidersResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(WatchProvidersResponse.self, from: json)
    }

    /// Region codes are dictionary keys, not property names. If the snake-case
    /// strategy ever touched them, "ES" would stop resolving and every lookup
    /// would silently return nothing.
    @Test("region codes survive the snake-case decoding strategy")
    func regionKeysAreUntouched() throws {
        let response = try decoded()
        #expect(response.results["ES"] != nil)
        #expect(response.results["US"] != nil)
    }

    @Test("a region with only a subscription decodes without its other categories")
    func partialRegionDecodes() throws {
        let spain = try #require(try decoded().results["ES"])

        #expect(spain.flatrate?.count == 1)
        #expect(spain.flatrate?.first?.providerName == "Netflix")
        #expect(spain.rent == nil)
        #expect(spain.buy == nil)
    }

    @Test("a region with more than one category keeps them apart")
    func fullRegionDecodes() throws {
        let us = try #require(try decoded().results["US"])

        #expect(us.flatrate?.first?.providerName == "Netflix")
        #expect(us.buy?.first?.providerName == "Apple TV")
    }

    /// The two states the section branches on: a region with something to show,
    /// and a region the title simply is not in.
    ///
    /// The first half is the one that carries weight. Without it, `isEmpty`
    /// hard-coded to `true` would satisfy every other test in this suite while
    /// hiding every watch option in the app.
    @Test("a populated region is not empty, and an absent one is absent")
    func populatedAndAbsentRegions() throws {
        let results = try decoded().results

        #expect(try #require(results["ES"]).isEmpty == false)
        #expect(try #require(results["US"]).isEmpty == false)
        #expect(results["JP"] == nil)
    }

    /// Each category on its own must be enough to make a region non-empty —
    /// otherwise a region offering only rentals would read as unavailable.
    @Test("any single category is enough to make a region non-empty")
    func eachCategoryCountsOnItsOwn() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let provider = """
        [{"logo_path": "/x.jpg", "provider_id": 1, "provider_name": "Test", "display_priority": 0}]
        """

        for category in ["flatrate", "rent", "buy", "free", "ads"] {
            let data = Data("""
            {"id": 1, "results": {"ES": {"link": "https://example.com", "\(category)": \(provider)}}}
            """.utf8)
            let response = try decoder.decode(WatchProvidersResponse.self, from: data)

            #expect(
                try #require(response.results["ES"]).isEmpty == false,
                "a region offering only \(category) should not read as unavailable"
            )
        }
    }

    /// A region can come back carrying a link and nothing else. Rendering that
    /// as a section with a heading and no rows would look broken.
    @Test("a region with a link but no providers reports itself empty")
    func linkOnlyRegionIsEmpty() throws {
        let bare = Data("""
        {"id": 1, "results": {"ES": {"link": "https://example.com"}}}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(WatchProvidersResponse.self, from: bare)

        #expect(try #require(response.results["ES"]).isEmpty)
    }

    @Test("a provider builds a logo URL from the same host as the posters")
    func logoURLIsBuilt() throws {
        let provider = try #require(try decoded().results["ES"]?.flatrate?.first)
        let url = try #require(provider.logoURL)

        #expect(url.absoluteString == "https://image.tmdb.org/t/p/w92/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg")
    }
}
