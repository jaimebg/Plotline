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
        #expect(split.averagedSeasonsAfter == [3, 4])
    }

    /// The time after the boundary counts every aired season; the verdict's
    /// average counts only the judgeable ones. Labelling that average with
    /// the whole range claimed a season it never included.
    @Test("the after-average names the seasons it covers when a thin season sits in the range")
    func afterAverageNamesItsSeasons() throws {
        let episodes = season(4, count: 10, runtime: 60) + season(5, count: 10, runtime: 60)
            + season(6, count: 2, runtime: 60) + season(7, count: 10, runtime: 60)
            + season(1, count: 10, runtime: 60) + season(2, count: 10, runtime: 60) + season(3, count: 10, runtime: 60)
        let decline = DeclinePoint(afterSeason: 3, averageBefore: 8.4, averageAfter: 7.1, seasonsAfter: [4, 5, 7])
        let split = try #require(plan(episodes, decline: decline)?.split)

        #expect(split.seasonsAfter == [4, 5, 6, 7])
        #expect(split.averagedSeasonsAfter == [4, 5, 7])
        #expect(WatchTimePlanner.splitLine(split)
                == "Seasons 1–3: 30 h, weighted avg 8.4 · After: seasons 4–7, 32 h, weighted avg 7.1 across seasons 4, 5, 7")
    }

    /// End to end: the engine leaves a thin season out of its decline, and the
    /// line says so rather than borrowing the planner's wider range.
    @Test("with the engine's own decline, a thin season past the boundary is named as left out of the average")
    func afterAverageFromTheEngine() throws {
        func rated(_ season: Int, _ ratings: [Double]) -> [EpisodeMetric] {
            ratings.enumerated().map { index, rating in
                EpisodeMetric(
                    episodeNumber: index + 1, seasonNumber: season, title: "S\(season)E\(index + 1)",
                    rating: rating, voteCount: 100, airDate: EpisodeFixtures.pastAirDate, runtime: 45
                )
            }
        }
        let high = [9.0, 9.1, 9.0, 9.1]
        let low = [7.0, 7.1, 7.0, 7.1]
        let episodes = rated(1, high) + rated(2, high) + rated(3, low) + rated(4, low)
            + rated(5, [7.0, 7.1]) + rated(6, low)

        guard case .analyzed(let analysis) = SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now),
              let decline = analysis.declinePoint else {
            Issue.record("expected the engine to find a decline after season 2")
            return
        }
        #expect(decline.seasonsAfter == [3, 4, 6])

        let split = try #require(plan(episodes, decline: decline)?.split)
        #expect(split.seasonsAfter == [3, 4, 5, 6])
        #expect(WatchTimePlanner.splitLine(split).hasSuffix("across seasons 3, 4, 6"))
    }

    @Test("a single averaged season is named in the singular")
    func singleAveragedSeason() {
        #expect(WatchTimePlanner.seasonList([4]) == "season 4")
        #expect(WatchTimePlanner.seasonList([4, 5, 7]) == "seasons 4, 5, 7")
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
