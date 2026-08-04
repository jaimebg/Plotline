import Foundation
import Testing
@testable import Plotline

/// The two seams the per-task reviews could not see, because each task only
/// ever looked at its own diff: the detail payload merge that carries the
/// series status, and the point where a live recomputation replaces the
/// bundled analysis.
@MainActor
@Suite("Detail analysis seams")
struct DetailAnalysisSeamTests {
    /// Breaking Bad — in the bundled dataset, five seasons, with an ending
    /// verdict the live path must not throw away.
    private let bundledSeriesId = 1396

    private func series(id: Int, hasEnded: Bool? = nil) -> MediaItem {
        var item = MediaItem(
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
        item.hasEnded = hasEnded
        return item
    }

    private func details(id: Int, hasEnded: Bool?, seasons: Int) -> MediaItem {
        var item = series(id: id, hasEnded: hasEnded)
        item.totalSeasons = seasons
        return item
    }

    // MARK: - The merge

    /// The status lives only on the detail payload; list payloads never carry
    /// it. Before this test existed, the normal merge branch dropped it, so
    /// every live recomputation ran blind and the ending verdict vanished
    /// seconds after the screen appeared.
    @Test("the detail payload's series status survives the merge")
    func mergeKeepsTheSeriesStatus() {
        let viewModel = MediaDetailViewModel(media: series(id: 1, hasEnded: nil))

        viewModel.applyDetails(details(id: 1, hasEnded: true, seasons: 5))

        #expect(viewModel.media.hasEnded == true)
        #expect(viewModel.totalSeasons == 5)
    }

    @Test("a confirmed running status survives the merge too")
    func mergeKeepsARunningStatus() {
        let viewModel = MediaDetailViewModel(media: series(id: 1, hasEnded: nil))

        viewModel.applyDetails(details(id: 1, hasEnded: false, seasons: 2))

        #expect(viewModel.media.hasEnded == false)
    }

    /// A payload that says nothing must not erase a status already known.
    @Test("an unknown status does not overwrite one already established")
    func mergeDoesNotEraseAKnownStatus() {
        let viewModel = MediaDetailViewModel(media: series(id: 1, hasEnded: true))

        viewModel.applyDetails(details(id: 1, hasEnded: nil, seasons: 5))

        #expect(viewModel.media.hasEnded == true)
    }

    // MARK: - The replacement

    /// `fetchAllSeasons` swallows per-season failures and falls back to asking
    /// for one season when the detail request fails, so a flaky connection can
    /// return a single cached season for a five-season series.
    @Test("a partial season fetch does not replace a fuller bundled analysis")
    func aFragmentDoesNotReplaceTheBundledAnalysis() throws {
        let viewModel = MediaDetailViewModel(media: series(id: bundledSeriesId))
        viewModel.loadBundledAnalysis()

        guard case .analyzed(let bundled) = viewModel.analysis else {
            Issue.record("Breaking Bad should be in the bundled dataset")
            return
        }
        #expect(bundled.seasons.count > 1)

        // One season came back; the rest failed.
        viewModel.episodesBySeason = [1: EpisodeFixtures.season(1, ratings: [7.0, 7.1, 7.0, 7.2, 7.1, 7.0])]
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .analyzed(let kept) = viewModel.analysis else {
            Issue.record("the bundled analysis should still be there")
            return
        }
        #expect(kept.seasons.count == bundled.seasons.count)
        #expect(viewModel.analysisSource == .bundled)
    }

    /// The mirror case: thin data must not turn a complete bundled analysis
    /// into "Not Enough Ratings Yet".
    @Test("an insufficient live result does not erase the bundled analysis")
    func insufficientLiveDataDoesNotEraseTheBundledAnalysis() {
        let viewModel = MediaDetailViewModel(media: series(id: bundledSeriesId))
        viewModel.loadBundledAnalysis()

        viewModel.episodesBySeason = [1: [EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0)]]
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .analyzed = viewModel.analysis else {
            Issue.record("expected the bundled analysis to survive, got \(String(describing: viewModel.analysis))")
            return
        }
        #expect(viewModel.analysisSource == .bundled)
    }

    /// Freshness still wins when the live data is genuinely as complete.
    @Test("a full season fetch still replaces the bundled analysis")
    func aCompleteFetchStillWins() {
        let viewModel = MediaDetailViewModel(media: series(id: bundledSeriesId))
        viewModel.loadBundledAnalysis()

        guard case .analyzed(let bundled) = viewModel.analysis else {
            Issue.record("Breaking Bad should be in the bundled dataset")
            return
        }

        let episodes = (1...bundled.seasons.count).flatMap { season in
            EpisodeFixtures.season(season, ratings: Array(repeating: 7.0, count: 6))
        }
        viewModel.episodesBySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        #expect(viewModel.analysisSource == .live)
    }

    /// A series with no bundled analysis has nothing to protect, so even a
    /// thin live result must reach the screen — otherwise the section stays
    /// silent where it could at least explain itself.
    @Test("a series absent from the bundle still gets its live result")
    func anUnbundledSeriesIsNotGuarded() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        viewModel.loadBundledAnalysis()
        #expect(viewModel.analysis == nil)

        viewModel.episodesBySeason = [1: [EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0)]]
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .insufficientData = viewModel.analysis else {
            Issue.record("expected the live result through, got \(String(describing: viewModel.analysis))")
            return
        }
        #expect(viewModel.analysisSource == .live)
    }
}
