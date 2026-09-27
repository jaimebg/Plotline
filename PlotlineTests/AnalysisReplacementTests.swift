import Foundation
import Testing
@testable import Plotline

/// When a live recomputation may replace the analysis on screen, and what a
/// partial season fetch is allowed to show.
@MainActor
@Suite("Analysis replacement")
struct AnalysisReplacementTests {
    /// Breaking Bad — in the bundled dataset.
    private let bundledSeriesId = 1396

    private func series(id: Int) -> MediaItem {
        MediaItem(
            id: id,
            overview: "A real, non-stub series.",
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 8.9,
            voteCount: 100,
            genreIds: nil,
            title: nil,
            releaseDate: nil,
            name: "Test Series",
            firstAirDate: nil,
            mediaType: .tv
        )
    }

    private func analyzed(seasons: [Int]) -> SeriesAnalysisResult {
        let episodes = seasons.flatMap { EpisodeFixtures.season($0, ratings: [8.0, 8.1, 8.2, 8.0]) }
        return SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now)
    }

    private func bySeason(_ seasons: [Int]) -> [Int: [EpisodeMetric]] {
        Dictionary(uniqueKeysWithValues: seasons.map {
            ($0, EpisodeFixtures.season($0, ratings: [7.0, 7.1, 7.2, 7.0, 7.1, 7.2]))
        })
    }

    // MARK: - The rule

    @Test("the same season count over a different set of seasons does not replace")
    func equalCountDifferentSeasonsIsKept() {
        let current = analyzed(seasons: [1, 2, 3])
        let fresh = analyzed(seasons: [1, 2, 4])

        #expect(!LiveSeriesAnalysis.shouldReplace(current, with: fresh, failedSeasons: []))
    }

    @Test("a superset of the seasons with no failures replaces")
    func supersetReplaces() {
        let current = analyzed(seasons: [1, 2, 3])
        let fresh = analyzed(seasons: [1, 2, 3, 4])

        #expect(LiveSeriesAnalysis.shouldReplace(current, with: fresh, failedSeasons: []))
    }

    @Test("a fetch with a failed season never replaces a full analysis")
    func failedSeasonsNeverReplace() {
        let current = analyzed(seasons: [1, 2, 3])
        // Even a result that covers every season the current one does.
        let fresh = analyzed(seasons: [1, 2, 3])

        #expect(!LiveSeriesAnalysis.shouldReplace(current, with: fresh, failedSeasons: [4]))
    }

    @Test("a refusal never replaces a full analysis")
    func refusalNeverReplaces() {
        #expect(!LiveSeriesAnalysis.shouldReplace(
            analyzed(seasons: [1, 2]),
            with: .insufficientData(.seasonsNotLoaded),
            failedSeasons: [3]
        ))
    }

    @Test("with nothing worth protecting, any fresh result goes through")
    func nothingToProtect() {
        #expect(LiveSeriesAnalysis.shouldReplace(nil, with: .insufficientData(.seasonsNotLoaded), failedSeasons: [2]))
        #expect(LiveSeriesAnalysis.shouldReplace(
            .insufficientData(.seasonsNotLoaded),
            with: analyzed(seasons: [1, 2]),
            failedSeasons: []
        ))
    }

    // MARK: - Through the view model

    @Test("a partial fetch of an unbundled series shows a refusal naming the gap, not a fragment")
    func unbundledPartialFetchIsRefused() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        viewModel.loadBundledAnalysis()
        #expect(viewModel.analysis == nil)

        viewModel.applySeasonFetch(
            SeasonFetchResult(episodesBySeason: bySeason([1, 2]), failedSeasons: [3]),
            asOf: EpisodeFixtures.now
        )

        #expect(viewModel.analysis == .insufficientData(.seasonsNotLoaded))
        #expect(viewModel.failedSeasons == [3])
        #expect(viewModel.analysisSource == .live)
        // The grid still has what did load.
        #expect(viewModel.availableSeasons == [1, 2])
    }

    @Test("a retry that loads the missing season replaces the refusal with the analysis")
    func retryRecovers() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        viewModel.applySeasonFetch(
            SeasonFetchResult(episodesBySeason: bySeason([1, 2]), failedSeasons: [3]),
            asOf: EpisodeFixtures.now
        )

        viewModel.applySeasonFetch(
            SeasonFetchResult(episodesBySeason: bySeason([3]), failedSeasons: []),
            asOf: EpisodeFixtures.now
        )

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis after the retry, got \(String(describing: viewModel.analysis))")
            return
        }
        #expect(analysis.seasons.map(\.seasonNumber) == [1, 2, 3])
        #expect(viewModel.failedSeasons.isEmpty)
    }

    @Test("a retry that fails outright does not wipe the seasons already loaded")
    func failedRetryKeepsLoadedSeasons() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        viewModel.applySeasonFetch(
            SeasonFetchResult(episodesBySeason: bySeason([1, 2, 3]), failedSeasons: []),
            asOf: EpisodeFixtures.now
        )
        guard case .analyzed = viewModel.analysis else {
            Issue.record("expected an analysis from the full fetch")
            return
        }

        viewModel.applySeasonFetch(
            SeasonFetchResult(episodesBySeason: [:], failedSeasons: [1, 2, 3]),
            asOf: EpisodeFixtures.now
        )

        #expect(viewModel.availableSeasons == [1, 2, 3])
        #expect(viewModel.failedSeasons.isEmpty)
        guard case .analyzed = viewModel.analysis else {
            Issue.record("the full analysis should survive a failed retry")
            return
        }
    }

    @Test("a partial fetch of a bundled series keeps the bundled analysis")
    func bundledPartialFetchKeepsBundle() {
        let viewModel = MediaDetailViewModel(media: series(id: bundledSeriesId))
        viewModel.loadBundledAnalysis()
        guard case .analyzed(let bundled) = viewModel.analysis else {
            Issue.record("Breaking Bad should be in the bundled dataset")
            return
        }

        let loaded = bundled.seasons.map(\.seasonNumber).dropLast()
        viewModel.applySeasonFetch(
            SeasonFetchResult(
                episodesBySeason: bySeason(Array(loaded)),
                failedSeasons: [bundled.seasons.last?.seasonNumber ?? 5]
            ),
            asOf: EpisodeFixtures.now
        )

        #expect(viewModel.analysisSource == .bundled)
        #expect(viewModel.analysis == .analyzed(bundled))
    }

    @Test("a complete fetch over a different set of seasons keeps the bundled analysis")
    func bundledEqualCountDifferentSetIsKept() {
        let viewModel = MediaDetailViewModel(media: series(id: bundledSeriesId))
        viewModel.loadBundledAnalysis()
        guard case .analyzed(let bundled) = viewModel.analysis else {
            Issue.record("Breaking Bad should be in the bundled dataset")
            return
        }

        // Same count, shifted by one: the bundled first season is missing.
        let shifted = bundled.seasons.map { $0.seasonNumber + 1 }
        viewModel.applySeasonFetch(
            SeasonFetchResult(episodesBySeason: bySeason(shifted), failedSeasons: []),
            asOf: EpisodeFixtures.now
        )

        #expect(viewModel.analysisSource == .bundled)
    }

    // MARK: - Averages and schedule

    @Test("the season averages the screen shows are the analysis' own figures")
    func seasonAveragesComeFromTheAnalysis() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        var episodes = bySeason([1, 2, 3])
        // A rated episode short of the vote floor: an unweighted average would
        // count it, the verdicts do not.
        episodes[1]?.append(EpisodeFixtures.episode(season: 1, number: 7, rating: 1.0, votes: 3))
        viewModel.applySeasonFetch(SeasonFetchResult(episodesBySeason: episodes, failedSeasons: []), asOf: EpisodeFixtures.now)

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis")
            return
        }
        let averages = viewModel.seasonAverages(asOf: EpisodeFixtures.now)
        for summary in analysis.seasons {
            #expect(averages[summary.seasonNumber] == summary.weightedAverage)
        }
    }

    @Test("the next scheduled date comes from a dated future episode, never a missing date")
    func nextScheduledAirDate() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        var episodes = bySeason([1])
        episodes[2] = [
            EpisodeFixtures.episode(season: 2, number: 1, rating: 0, votes: 0, airDate: nil),
            EpisodeFixtures.episode(season: 2, number: 2, rating: 0, votes: 0, airDate: "2020-02-01")
        ]
        viewModel.episodesBySeason = episodes

        let expected = EpisodeMetric.parseAirDate("2020-02-01")
        #expect(viewModel.nextScheduledAirDate(asOf: EpisodeFixtures.now) == expected)

        viewModel.episodesBySeason = bySeason([1])
        #expect(viewModel.nextScheduledAirDate(asOf: EpisodeFixtures.now) == nil)
    }

    // MARK: - No season count, no seasons

    private func details(id: Int, seasons: Int, hasEnded: Bool? = nil) -> MediaItem {
        var item = series(id: id)
        item.totalSeasons = seasons
        item.hasEnded = hasEnded
        return item
    }

    /// One season with runtimes and crew, so every episode-derived section
    /// has something to show once it is allowed to.
    private var timedSeason: [EpisodeMetric] {
        [8.0, 8.0, 8.0, 9.0, 9.0, 9.0].enumerated().map { index, rating in
            EpisodeMetric(
                episodeNumber: index + 1, seasonNumber: 1, title: "S1E\(index + 1)",
                rating: rating, voteCount: 100, airDate: EpisodeFixtures.pastAirDate,
                directors: [index < 3 ? "Low" : "High"], writers: ["Solo"], runtime: 45
            )
        }
    }

    /// List payloads and bundled entries carry no season count, so a failed
    /// detail request left `totalSeasons` at 1: season 1 alone came back with
    /// no failure to report and was analysed as the whole run.
    @Test("without the details' season count no season is fetched, and the gap is stated with a retry")
    func noSeasonCountFetchesNothing() async {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        #expect(!viewModel.knowsSeasonCount)

        // Returns before any request: the guard is the first thing it checks.
        await viewModel.fetchAllSeasons()

        #expect(viewModel.episodesBySeason.isEmpty)
        #expect(viewModel.analysis == nil)
        #expect(viewModel.failedSeasons.isEmpty)
        #expect(!viewModel.isLoadingAllSeasons)
        // The grid's "unavailable" state, which carries Try Again.
        #expect(viewModel.episodesError == MediaDetailViewModel.seasonCountUnavailableMessage)
        #expect(!viewModel.shouldShowEpisodeGrid)
    }

    @Test("a bundled series with no details keeps its bundled analysis and derives nothing from season 1")
    func noSeasonCountKeepsTheBundle() async throws {
        let viewModel = MediaDetailViewModel(media: series(id: bundledSeriesId))
        viewModel.loadBundledAnalysis()
        let bundled = try #require(viewModel.analyzedResult, "Breaking Bad should be in the bundled dataset")

        await viewModel.fetchAllSeasons()

        #expect(viewModel.analysis == .analyzed(bundled))
        #expect(viewModel.analysisSource == .bundled)
        #expect(viewModel.episodesError == MediaDetailViewModel.seasonCountUnavailableMessage)
        #expect(viewModel.visibleWatchTimePlan == nil)
        #expect(viewModel.visibleCrewComparison == nil)
        #expect(viewModel.shareCardEpisodes.isEmpty)
        #expect(viewModel.currentStatus == .notLoaded)
    }

    @Test("watch time, crew and the share card's episode curve wait for the season count")
    func derivedSectionsNeedTheSeasonCount() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        viewModel.applySeasonFetch(
            SeasonFetchResult(episodesBySeason: [1: timedSeason], failedSeasons: []),
            asOf: EpisodeFixtures.now
        )
        #expect(viewModel.analyzedResult != nil)
        #expect(viewModel.visibleWatchTimePlan == nil)
        #expect(viewModel.visibleCrewComparison == nil)
        #expect(viewModel.shareCardEpisodes.isEmpty)

        viewModel.applyDetails(details(id: -1, seasons: 1))

        #expect(viewModel.knowsSeasonCount)
        #expect(viewModel.visibleWatchTimePlan != nil)
        #expect(viewModel.visibleCrewComparison != nil)
        #expect(viewModel.shareCardEpisodes.count == timedSeason.count)
    }

    @Test("a detail payload without a season count does not count as knowing it")
    func detailsWithoutASeasonCount() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        viewModel.applyDetails(series(id: -1))

        #expect(!viewModel.knowsSeasonCount)
        #expect(viewModel.totalSeasons == 1)
    }

    // MARK: - The share card's curve

    @Test("with the bundled analysis kept over a partial fetch, the card plots the analysis's season averages")
    func cardOverPartialFetchUsesSeasonAverages() throws {
        let viewModel = MediaDetailViewModel(media: series(id: bundledSeriesId))
        viewModel.loadBundledAnalysis()
        let bundled = try #require(viewModel.analyzedResult)
        let all = bundled.seasons.map(\.seasonNumber)
        viewModel.applyDetails(details(id: bundledSeriesId, seasons: all.count, hasEnded: true))

        viewModel.applySeasonFetch(
            SeasonFetchResult(episodesBySeason: bySeason(Array(all.dropLast())), failedSeasons: [all.last ?? 5]),
            asOf: EpisodeFixtures.now
        )
        #expect(viewModel.analysisSource == .bundled)
        #expect(viewModel.shareCardEpisodes.isEmpty)

        let card = VerdictCardContent(
            title: "Breaking Bad",
            analysis: bundled,
            episodes: viewModel.shareCardEpisodes,
            status: viewModel.currentStatus,
            nextEpisodeDate: nil,
            asOf: EpisodeFixtures.now
        )
        #expect(card.curve == bundled.seasons.map(\.weightedAverage))
        #expect(card.curveCaption == "Season averages, weighted by votes")
        #expect(card.basis.hasSuffix("across \(bundled.seasons.count) seasons."))
    }

    @Test("a bundled analysis kept over a complete fetch still plots season averages")
    func cardOverKeptBundleUsesSeasonAverages() throws {
        let viewModel = MediaDetailViewModel(media: series(id: bundledSeriesId))
        viewModel.loadBundledAnalysis()
        let bundled = try #require(viewModel.analyzedResult)
        let shifted = bundled.seasons.map { $0.seasonNumber + 1 }
        viewModel.applyDetails(details(id: bundledSeriesId, seasons: shifted.count + 1))

        viewModel.applySeasonFetch(SeasonFetchResult(episodesBySeason: bySeason(shifted), failedSeasons: []), asOf: EpisodeFixtures.now)

        #expect(viewModel.analysisSource == .bundled)
        #expect(viewModel.failedSeasons.isEmpty)
        #expect(viewModel.shareCardEpisodes.isEmpty)
    }

    @Test("a live analysis with a season missing from a later fetch plots season averages")
    func cardWithFailedSeasonUsesSeasonAverages() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        viewModel.applyDetails(details(id: -1, seasons: 3))
        viewModel.applySeasonFetch(SeasonFetchResult(episodesBySeason: bySeason([1, 2, 3]), failedSeasons: []), asOf: EpisodeFixtures.now)
        #expect(viewModel.analysisSource == .live)
        #expect(viewModel.shareCardEpisodes.count == 18)

        // A fourth season appeared and failed: the live three-season analysis
        // stays, and its episodes are no longer the whole run.
        viewModel.applySeasonFetch(SeasonFetchResult(episodesBySeason: [:], failedSeasons: [4]), asOf: EpisodeFixtures.now)
        #expect(viewModel.failedSeasons == [4])
        #expect(viewModel.analysisSource == .live)
        #expect(viewModel.shareCardEpisodes.isEmpty)
    }
}
