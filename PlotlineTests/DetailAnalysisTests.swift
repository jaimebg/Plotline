import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("Detail analysis")
struct DetailAnalysisTests {
    /// Breaking Bad — in the bundled dataset, so its analysis must be on hand
    /// before a single request is made.
    private let bundledSeriesId = 1396

    private func media(id: Int, type: MediaType) -> MediaItem {
        MediaItem(
            id: id,
            overview: "",
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: nil,
            title: type == .movie ? "Test Movie" : nil,
            releaseDate: nil,
            name: type == .tv ? "Test Series" : nil,
            firstAirDate: nil,
            mediaType: type
        )
    }

    @Test("a bundled series has its analysis before any network call")
    func bundledAnalysisIsImmediate() {
        let viewModel = MediaDetailViewModel(media: media(id: bundledSeriesId, type: .tv))
        viewModel.loadBundledAnalysis()

        guard case .analyzed = viewModel.analysis else {
            Issue.record("expected a bundled analysis, got \(String(describing: viewModel.analysis))")
            return
        }
        #expect(viewModel.analysisSource == .bundled)
    }

    @Test("a bundled series is analysable with no episodes loaded at all")
    func bundledAnalysisNeedsNoEpisodes() {
        let viewModel = MediaDetailViewModel(media: media(id: bundledSeriesId, type: .tv))
        viewModel.loadBundledAnalysis()

        // Nothing has been fetched: this is the offline first-frame case.
        #expect(viewModel.episodesBySeason.isEmpty)

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis with no episodes loaded")
            return
        }
        #expect(analysis.score.value > 0)
        #expect(!analysis.seasons.isEmpty)
    }

    @Test("a series absent from the bundle has no analysis until episodes arrive")
    func unbundledSeriesHasNothingYet() {
        let viewModel = MediaDetailViewModel(media: media(id: -1, type: .tv))
        viewModel.loadBundledAnalysis()

        #expect(viewModel.analysis == nil)
    }

    @Test("a movie never gets an analysis")
    func moviesAreNotAnalysed() {
        let viewModel = MediaDetailViewModel(media: media(id: bundledSeriesId, type: .movie))
        viewModel.loadBundledAnalysis()

        #expect(viewModel.analysis == nil)
    }

    @Test("recomputing from fresh episodes replaces the bundled analysis")
    func freshEpisodesWin() {
        let viewModel = MediaDetailViewModel(media: media(id: bundledSeriesId, type: .tv))
        viewModel.loadBundledAnalysis()
        #expect(viewModel.analysisSource == .bundled)

        // A flat, unremarkable run — nothing like the bundled Breaking Bad.
        let episodes = (1...3).flatMap { season in
            EpisodeFixtures.season(season, ratings: Array(repeating: 7.0, count: 6))
        }
        viewModel.episodesBySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis")
            return
        }
        #expect(viewModel.analysisSource == .live)
        #expect(analysis.seasons.count == 3)
    }

    /// The regression Task 1 exists to prevent: a bundled series shows an
    /// ending verdict, and the live recomputation must not silently drop it.
    @Test("a confirmed ended status survives the live recomputation")
    func endedStatusReachesTheEngine() {
        var ended = media(id: -1, type: .tv)
        ended.hasEnded = true

        let viewModel = MediaDetailViewModel(media: ended)
        let episodes = EpisodeFixtures.season(1, ratings: [6.0, 6.1, 6.0, 6.2, 6.1, 6.0])
            + EpisodeFixtures.season(2, ratings: [8.8, 8.9, 9.0, 8.7, 8.9, 9.1])
        viewModel.episodesBySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis")
            return
        }
        #expect(analysis.endingVerdict != nil)
    }

    /// Pins the boundary the ending-verdict test cannot see: `endingVerdict`
    /// requires `hasEnded == true` outright, so it stays nil for both `nil`
    /// and `false` and cannot catch a `media.hasEnded ?? false` regression in
    /// `recomputeAnalysis`. `isOngoing` can, because the engine treats those
    /// two inputs differently — `nil` falls back to inferring from scheduled
    /// episodes, `false` is taken as a confirmed "still running".
    @Test("an unknown ended status is not reported as still running")
    func unknownStatusIsNotOngoing() {
        let viewModel = MediaDetailViewModel(media: media(id: -1, type: .tv))
        let episodes = EpisodeFixtures.season(1, ratings: [6.0, 6.1, 6.0, 6.2, 6.1, 6.0])
            + EpisodeFixtures.season(2, ratings: [8.8, 8.9, 9.0, 8.7, 8.9, 9.1])
        viewModel.episodesBySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis")
            return
        }
        // Every episode is past-dated and nothing is scheduled, so an unknown
        // status must not read as ongoing.
        #expect(analysis.isOngoing == false)
    }

    @Test("a confirmed still-running status is reported as ongoing")
    func confirmedRunningIsOngoing() {
        var running = media(id: -1, type: .tv)
        running.hasEnded = false

        let viewModel = MediaDetailViewModel(media: running)
        let episodes = EpisodeFixtures.season(1, ratings: [6.0, 6.1, 6.0, 6.2, 6.1, 6.0])
            + EpisodeFixtures.season(2, ratings: [8.8, 8.9, 9.0, 8.7, 8.9, 9.1])
        viewModel.episodesBySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .analyzed(let analysis) = viewModel.analysis else {
            Issue.record("expected an analysis")
            return
        }
        #expect(analysis.isOngoing == true)
    }

    @Test("too little data yields insufficientData rather than a made-up verdict")
    func thinDataIsRefused() {
        let viewModel = MediaDetailViewModel(media: media(id: -1, type: .tv))
        viewModel.episodesBySeason = [1: [EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0)]]
        viewModel.recomputeAnalysis(asOf: EpisodeFixtures.now)

        guard case .insufficientData = viewModel.analysis else {
            Issue.record("expected .insufficientData, got \(String(describing: viewModel.analysis))")
            return
        }
    }
}
