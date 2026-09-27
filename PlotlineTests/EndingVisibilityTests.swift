import Foundation
import Testing
@testable import Plotline

/// An ending verdict is a claim about a finished run, and an analysis can
/// outlive the status it was computed with. The detail screen, the share card
/// and Compare all gate it through `SeriesAnalysis.visibleEndingVerdict(under:)`.
@MainActor
@Suite("Ending verdict under the current status")
struct EndingVisibilityTests {
    private let ending = EndingVerdict(
        kind: .endsStrong, finalSeason: 3, finalSeasonAverage: 8.6, peakSeason: 3, peakSeasonAverage: 8.6
    )

    /// An analysis computed when the series had ended — as the engine only
    /// writes an ending verdict then — unless `isOngoing` says otherwise.
    private func analysis(ending: EndingVerdict?, isOngoing: Bool = false) -> SeriesAnalysis {
        SeriesAnalysis(
            seasons: (1...3).map {
                SeasonSummary(seasonNumber: $0, weightedAverage: 8.0 + Double($0) * 0.2, standardDeviation: 0.2,
                              reliableEpisodeCount: 8, airedEpisodeCount: 8, bestEpisode: nil, worstEpisode: nil)
            },
            bestSeason: 3,
            worstSeason: 1,
            declinePoint: nil,
            declineTest: .tooFewSeasons(judgeable: 3),
            consistency: Consistency(rating: .steady, standardDeviation: 0.4, highestRated: nil, lowestRated: nil),
            standoutHighs: [],
            standoutLows: [],
            openingVerdict: nil,
            endingVerdict: ending,
            score: PlotlineScore(value: 84, level: 86, consistency: 70, trajectory: 60),
            isOngoing: isOngoing
        )
    }

    private func series(id: Int) -> MediaItem {
        MediaItem(
            id: id, overview: "A real, non-stub series.", posterPath: nil, backdropPath: nil,
            voteAverage: 8, voteCount: 100, genreIds: nil, title: nil, releaseDate: nil,
            name: "Test Series", firstAirDate: nil, mediaType: .tv
        )
    }

    // MARK: - The rule

    @Test("with details loaded, the verdict shows only for a series TMDB currently reports as ended")
    func reportedStatus() {
        let ended = analysis(ending: ending)
        #expect(ended.visibleEndingVerdict(under: .reported(hasEnded: true)) == ending)
        // Revived since the analysis was computed.
        #expect(ended.visibleEndingVerdict(under: .reported(hasEnded: false)) == nil)
        // A status TMDB's mapping cannot place is not an ending.
        #expect(ended.visibleEndingVerdict(under: .reported(hasEnded: nil)) == nil)
    }

    @Test("without details, the analysis's own record decides, conservatively")
    func notLoaded() {
        #expect(analysis(ending: ending).visibleEndingVerdict(under: .notLoaded) == ending)
        #expect(analysis(ending: ending, isOngoing: true).visibleEndingVerdict(under: .notLoaded) == nil)
    }

    @Test("no verdict in the analysis means none on screen, whatever the status")
    func noVerdict() {
        for status in [.reported(hasEnded: true), .reported(hasEnded: false), .reported(hasEnded: nil), .notLoaded] as [CurrentSeriesStatus] {
            #expect(analysis(ending: nil).visibleEndingVerdict(under: status) == nil)
        }
    }

    // MARK: - The three places it is shown

    @Test("the detail screen reports the status only once the details have loaded")
    func detailScreenStatus() {
        let viewModel = MediaDetailViewModel(media: series(id: -1))
        #expect(viewModel.currentStatus == .notLoaded)

        var details = series(id: -1)
        details.hasEnded = false
        details.totalSeasons = 3
        viewModel.applyDetails(details)
        #expect(viewModel.currentStatus == .reported(hasEnded: false))
    }

    @Test("the share card withholds a revived series' ending")
    func cardUnderRevival() {
        let revived = VerdictCardContent(
            title: "Show", analysis: analysis(ending: ending), episodes: [],
            status: .reported(hasEnded: false), nextEpisodeDate: nil
        )
        #expect(revived.ending == nil)

        let ended = VerdictCardContent(
            title: "Show", analysis: analysis(ending: ending), episodes: [],
            status: .reported(hasEnded: true), nextEpisodeDate: nil
        )
        #expect(ended.ending?.title == SeriesVerdictsView.endingTitle(ending))

        let offline = VerdictCardContent(
            title: "Show", analysis: analysis(ending: ending), episodes: [],
            status: .notLoaded, nextEpisodeDate: nil
        )
        #expect(offline.ending?.title == SeriesVerdictsView.endingTitle(ending))
    }

    @Test("Compare applies the same rule to a bundled seed")
    func compareUnderRevival() throws {
        func column(_ status: CurrentSeriesStatus) throws -> CompareAnalysisColumn {
            let entry = CompareAnalysisEntry.make(
                slotIndex: 0, label: "Show", isSeries: true, isRetrying: false,
                analysis: .seeded(bundled: analysis(ending: ending), status: status)
            )
            guard case .analyzed(let column) = entry.state else {
                Issue.record("expected an analysed column")
                throw CancellationError()
            }
            return column
        }

        let revived = CompareAnalysisTable.ending(try column(.reported(hasEnded: false)))
        #expect(revived.value == "No ending to judge")
        #expect(revived.detail == "TMDB lists it as returning or in production")

        #expect(CompareAnalysisTable.ending(try column(.reported(hasEnded: true))).value == "Ends on a high")
        #expect(CompareAnalysisTable.ending(try column(.notLoaded)).value == "Ends on a high")
        #expect(CompareAnalysisTable.ending(try column(.reported(hasEnded: nil))).value == "No ending to judge")
    }
}
