import Foundation
@testable import Plotline

/// Builders for analysis test data.
///
/// Air dates default to a fixed date well in the past so `hasAired(asOf:)` is
/// deterministic; pass a future date explicitly to model an unaired episode.
enum EpisodeFixtures {
    static let pastAirDate = "2010-01-01"
    static let futureAirDate = "2999-01-01"

    /// A reference "now" for the engine. Fixed so tests never depend on the clock.
    static let now: Date = {
        var components = DateComponents()
        components.year = 2020
        components.month = 1
        components.day = 1
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    static func episode(
        season: Int,
        number: Int,
        rating: Double,
        votes: Int = 100,
        airDate: String? = pastAirDate,
        title: String? = nil
    ) -> EpisodeMetric {
        EpisodeMetric(
            episodeNumber: number,
            seasonNumber: season,
            title: title ?? "S\(season)E\(number)",
            rating: rating,
            voteCount: votes,
            airDate: airDate
        )
    }

    /// A whole season from a list of ratings, numbered from 1.
    static func season(_ season: Int, ratings: [Double], votes: Int = 100) -> [EpisodeMetric] {
        ratings.enumerated().map { index, rating in
            episode(season: season, number: index + 1, rating: rating, votes: votes)
        }
    }
}
