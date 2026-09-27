import Foundation
import Testing
@testable import Plotline

@Suite("WatchTimePlanner")
struct WatchTimePlannerTests {
    private func episode(_ season: Int, _ number: Int, runtime: Int?, airDate: String = EpisodeFixtures.pastAirDate) -> EpisodeMetric {
        EpisodeMetric(
            episodeNumber: number,
            seasonNumber: season,
            title: "S\(season)E\(number)",
            rating: 8,
            voteCount: 100,
            airDate: airDate,
            runtime: runtime
        )
    }

    private func season(_ number: Int, count: Int, runtime: Int?) -> [EpisodeMetric] {
        (1...count).map { episode(number, $0, runtime: runtime) }
    }

    private func plan(_ episodes: [EpisodeMetric], decline: DeclinePoint? = nil) -> WatchTimePlan? {
        WatchTimePlanner.plan(episodes: episodes, declinePoint: decline, asOf: EpisodeFixtures.now)
    }

    @Test("totals aired main-run runtime per season and overall")
    func totals() throws {
        let episodes = season(1, count: 10, runtime: 45) + season(2, count: 8, runtime: 60)
        let result = try #require(plan(episodes))
        #expect(result.totalMinutes == 450 + 480)
        #expect(result.seasons.map(\.minutes) == [450, 480])
        #expect(result.knownRuntimeCount == 18)
        #expect(result.airedCount == 18)
    }

    @Test("specials and unaired episodes are left out")
    func excludesSpecialsAndUnaired() throws {
        let episodes = season(1, count: 4, runtime: 50)
            + [episode(0, 1, runtime: 90), episode(1, 5, runtime: 50, airDate: EpisodeFixtures.futureAirDate)]
        let result = try #require(plan(episodes))
        #expect(result.totalMinutes == 200)
        #expect(result.airedCount == 4)
        #expect(result.seasons.map(\.seasonNumber) == [1])
    }

    @Test("below 80% runtime coverage there is no plan")
    func lowCoverageHides() {
        // 7 of 10 known.
        let episodes = (1...7).map { episode(1, $0, runtime: 45) } + (8...10).map { episode(1, $0, runtime: nil) }
        #expect(plan(episodes) == nil)
    }

    @Test("at exactly 80% coverage the plan shows, and says what is missing")
    func coverageAtThresholdShows() throws {
        let episodes = (1...8).map { episode(1, $0, runtime: 45) } + (9...10).map { episode(1, $0, runtime: nil) }
        let result = try #require(plan(episodes))
        #expect(result.knownRuntimeCount == 8)
        #expect(WatchTimePlanner.summary(result) == "About 6 h across 1 season; runtime known for 8 of 10 aired episodes.")
    }

    @Test("a zero runtime counts as unknown")
    func zeroRuntimeIsUnknown() {
        let episodes = (1...5).map { episode(1, $0, runtime: 0) }
        #expect(plan(episodes) == nil)
    }

    @Test("nothing aired, no plan")
    func nothingAired() {
        #expect(plan([episode(1, 1, runtime: 45, airDate: EpisodeFixtures.futureAirDate)]) == nil)
    }

    @Test("the decline split sums each side and carries the verdict's averages")
    func declineSplit() throws {
        let episodes = season(1, count: 10, runtime: 60) + season(2, count: 10, runtime: 60)
            + season(3, count: 10, runtime: 60) + season(4, count: 10, runtime: 45)
        let decline = DeclinePoint(afterSeason: 2, averageBefore: 8.44, averageAfter: 7.06, seasonsAfter: [3, 4])
        let split = try #require(plan(episodes, decline: decline)?.split)
        #expect(split.seasonsBefore == [1, 2])
        #expect(split.minutesBefore == 1200)
        #expect(split.seasonsAfter == [3, 4])
        #expect(split.minutesAfter == 1050)
        #expect(WatchTimePlanner.splitLine(split)
                == "Seasons 1–2: 20 h, weighted avg 8.4 · After: seasons 3–4, 18 h, weighted avg 7.1")
    }

    @Test("no decline, no split")
    func noDeclineNoSplit() throws {
        #expect(try #require(plan(season(1, count: 5, runtime: 30))).split == nil)
    }

    @Test("durations read as minutes, then tenths of an hour, then whole hours")
    func durations() {
        #expect(WatchTimePlanner.duration(minutes: 45) == "45 min")
        #expect(WatchTimePlanner.duration(minutes: 89) == "89 min")
        #expect(WatchTimePlanner.duration(minutes: 90) == "1.5 h")
        #expect(WatchTimePlanner.duration(minutes: 420) == "7 h")
        #expect(WatchTimePlanner.duration(minutes: 456) == "7.6 h")
        #expect(WatchTimePlanner.duration(minutes: 3_720) == "62 h")
        #expect(WatchTimePlanner.duration(minutes: 3_750) == "63 h")
        #expect(WatchTimePlanner.spokenDuration(minutes: 3_720) == "62 hours")
        #expect(WatchTimePlanner.spokenDuration(minutes: 45) == "45 minutes")
    }

    @Test("full coverage is stated as all episodes")
    func fullCoverageSummary() throws {
        let result = try #require(plan(season(1, count: 31, runtime: 60) + season(2, count: 31, runtime: 60)))
        #expect(WatchTimePlanner.summary(result) == "About 62 h across 2 seasons; runtime known for all 62 aired episodes.")
    }

    @Test("the copy never tells anyone where to stop")
    func noAdvice() throws {
        let episodes = season(1, count: 10, runtime: 60) + season(2, count: 10, runtime: 60) + season(3, count: 10, runtime: 60)
        let decline = DeclinePoint(afterSeason: 1, averageBefore: 8.5, averageAfter: 7.5, seasonsAfter: [2, 3])
        let result = try #require(plan(episodes, decline: decline))
        let text = (WatchTimePlanner.summary(result) + " " + WatchTimePlanner.splitLine(try #require(result.split))).lowercased()
        for banned in ["stop", "skip", "worth", "quit", "should"] {
            #expect(!text.contains(banned))
        }
    }

    @Test("the season payload's runtime reaches EpisodeMetric")
    func runtimeIsCarried() throws {
        let json = """
        {"id": 1, "name": "S1", "season_number": 1, "episodes": [
          {"id": 10, "name": "Pilot", "episode_number": 1, "season_number": 1, "air_date": "2008-01-20",
           "still_path": null, "vote_average": 8.9, "vote_count": 412, "overview": "", "runtime": 58},
          {"id": 11, "name": "Two", "episode_number": 2, "season_number": 1, "air_date": "2008-01-27",
           "still_path": null, "vote_average": 8.5, "vote_count": 300, "overview": "", "runtime": null}
        ]}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let metrics = try decoder.decode(TMDBSeasonResponse.self, from: Data(json.utf8)).toEpisodeMetrics()
        #expect(metrics.map(\.runtime) == [58, nil])
    }
}
