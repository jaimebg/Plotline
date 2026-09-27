import Foundation
import Testing
@testable import Plotline

/// A season cached while it is still airing must not hold its newest episodes
/// at zero votes for a week.
@Suite("Season cache lifetime")
struct SeasonCachingTests {
    /// 2026-06-15, midday UTC.
    private let now = Date(timeIntervalSince1970: 1_781_524_800)

    private func episode(_ number: Int, airDate: String?) -> EpisodeMetric {
        EpisodeMetric(
            episodeNumber: number,
            seasonNumber: 1,
            title: "E\(number)",
            rating: 8,
            voteCount: 10,
            airDate: airDate
        )
    }

    @Test("a season that aired long ago keeps the long lifetime")
    func settledSeason() {
        let episodes = [episode(1, airDate: "2020-01-01"), episode(2, airDate: "2020-01-08")]
        #expect(TMDBService.seasonCacheMaxAge(for: episodes, now: now) == TMDBService.settledSeasonMaxAge)
    }

    @Test("an episode still to air shortens the lifetime")
    func futureEpisode() {
        let episodes = [episode(1, airDate: "2026-06-01"), episode(2, airDate: "2026-07-01")]
        #expect(TMDBService.seasonCacheMaxAge(for: episodes, now: now) == TMDBService.airingSeasonMaxAge)
    }

    @Test("an episode with no air date shortens the lifetime")
    func undatedEpisode() {
        let episodes = [episode(1, airDate: "2020-01-01"), episode(2, airDate: nil)]
        #expect(TMDBService.seasonCacheMaxAge(for: episodes, now: now) == TMDBService.airingSeasonMaxAge)
    }

    /// Aired, but the votes are still arriving.
    @Test("an episode aired within the last two weeks shortens the lifetime")
    func recentlyAired() {
        let episodes = [episode(1, airDate: "2026-05-01"), episode(2, airDate: "2026-06-10")]
        #expect(TMDBService.seasonCacheMaxAge(for: episodes, now: now) == TMDBService.airingSeasonMaxAge)
    }

    @Test("just past the recent window, the season counts as settled")
    func justSettled() {
        let episodes = [episode(1, airDate: "2026-05-01"), episode(2, airDate: "2026-05-31")]
        #expect(TMDBService.seasonCacheMaxAge(for: episodes, now: now) == TMDBService.settledSeasonMaxAge)
    }

    @Test("the short lifetime is shorter than the long one")
    func ordering() {
        #expect(TMDBService.airingSeasonMaxAge < TMDBService.settledSeasonMaxAge)
    }

    @Test("a fetch result is complete only when no season failed")
    func completeness() {
        var result = SeasonFetchResult(episodesBySeason: [1: [episode(1, airDate: "2020-01-01")]])
        #expect(result.isComplete)

        result.failedSeasons = [2]
        #expect(!result.isComplete)
    }
}
