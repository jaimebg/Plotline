import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("Series verdict copy")
struct SeriesVerdictCopyTests {
    private func ending(final: Int, finalAverage: Double, peak: Int, peakAverage: Double) -> EndingVerdict {
        EndingVerdict(
            kind: .endsStrong,
            finalSeason: final,
            finalSeasonAverage: finalAverage,
            peakSeason: peak,
            peakSeasonAverage: peakAverage
        )
    }

    /// Caught on screen, not by a test: Breaking Bad's real bundled analysis
    /// rendered "Season 5 averaged 9.0; its best, season 5, averaged 9.0." The
    /// last season being the peak is the ordinary case for `endsStrong`, so the
    /// comparative phrasing has to give way to a single statement.
    @Test("a series whose last season is its peak does not compare it to itself")
    func peakFinalSeasonIsStatedOnce() {
        let copy = SeriesVerdictsView.endingEvidence(
            ending(final: 5, finalAverage: 9.0, peak: 5, peakAverage: 9.0)
        )

        #expect(copy == "Season 5, its highest-rated, averaged 9.0.")
        // The old phrasing set the season against itself. No comparative
        // clause may survive when there is nothing to compare against.
        #expect(!copy.contains("its best,"))
        #expect(copy.lowercased().components(separatedBy: "season").count - 1 == 1)
    }

    @Test("a series that peaked earlier still gets the comparison")
    func earlierPeakIsCompared() {
        let copy = SeriesVerdictsView.endingEvidence(
            ending(final: 8, finalAverage: 7.2, peak: 4, peakAverage: 9.1)
        )

        #expect(copy == "Season 8 averaged 7.2; its best, season 4, averaged 9.1.")
    }

    // MARK: - Consistency

    private func reference(season: Int, episode: Int, rating: Double) -> EpisodeReference {
        EpisodeReference(
            id: season * 100 + episode,
            seasonNumber: season,
            episodeNumber: episode,
            title: "S\(season)E\(episode)",
            rating: rating
        )
    }

    private func consistency(high: Double, low: Double) -> Consistency {
        Consistency(
            rating: .steady,
            standardDeviation: 0.1,
            highestRated: reference(season: 1, episode: 1, rating: high),
            lowestRated: reference(season: 3, episode: 6, rating: low)
        )
    }

    /// Same shape as the ending defect: two different episodes carrying the
    /// same rating are not a range, and naming both makes it look like one.
    @Test("a flat run is not described as a range")
    func flatRunIsNotARange() {
        let copy = SeriesVerdictsView.consistencyEvidence(consistency(high: 8.0, low: 8.0))

        #expect(copy == "Every rated episode sits at 8.0.")
        #expect(!copy.lowercased().contains("down to"))
    }

    @Test("a real spread is still shown end to end")
    func realSpreadIsShown() {
        let copy = SeriesVerdictsView.consistencyEvidence(consistency(high: 9.4, low: 7.8))

        #expect(copy == "Ranges from S1E1 at 9.4 down to S3E6 at 7.8.")
    }

    // MARK: - Season spread

    /// §5 of the spec: a verdict with no numbers under it is decoration. The
    /// season averages were already on hand.
    @Test("the best/weakest pair shows the averages behind it")
    func seasonSpreadCarriesItsNumbers() {
        let analysis = DatasetStore.shared.entries
            .first { $0.analysis.bestSeason != nil && $0.analysis.worstSeason != nil }?
            .analysis

        guard let analysis, let best = analysis.bestSeason, let worst = analysis.worstSeason else {
            Issue.record("the bundled dataset should contain a series with both seasons ranked")
            return
        }

        let copy = SeriesVerdictsView.seasonSpreadEvidence(analysis, best: best, worst: worst)

        #expect(copy.contains("averaged"))
        #expect(copy != "Measured across the seasons with enough rated episodes to judge.")
    }

    // MARK: - Opening

    /// The opening run is the first six *reliable* episodes, so "First 6
    /// episodes" claimed a window the engine never measured whenever an early
    /// episode was short of votes.
    @Test("the opening evidence says the episodes were the ones with enough votes")
    func openingEvidenceIsQualified() {
        let opening = OpeningVerdict(
            kind: .slowStart,
            openingAverage: 7.0,
            remainderAverage: 8.4,
            episodesConsidered: (1...6).map { reference(season: 1, episode: $0, rating: 7.0) },
            improvesAtSeason: nil
        )

        #expect(
            SeriesVerdictsView.openingEvidence(opening)
                == "The first 6 episodes with enough votes averaged 7.0, against 8.4 for the rest."
        )
    }

    // MARK: - Run status

    /// TMDB's status proves what TMDB lists, not that anything is coming.
    @Test("a returning status with nothing dated says only what TMDB lists")
    func returningWithoutADate() {
        let status = SeriesVerdictsView.runStatus(hasEnded: false, nextEpisodeDate: nil)

        #expect(status?.title == "Listed as returning")
        #expect(status?.evidence.contains("TMDB lists") == true)
        #expect(status?.evidence.contains("on the way") == false)
    }

    @Test("a dated future episode is the only thing that says more are scheduled")
    func datedNextEpisode() {
        let date = EpisodeMetric.parseAirDate("2031-03-14")
        let status = SeriesVerdictsView.runStatus(hasEnded: false, nextEpisodeDate: date)

        #expect(status?.title == "Next episode scheduled")
        #expect(status?.evidence.contains("2031") == true)
        #expect(status?.evidence.contains("14") == true)
    }

    /// `hasEnded == nil` is unknown: it may render neither "Ended" nor
    /// "Returning".
    @Test("an unknown status renders no run-status row")
    func unknownStatusSaysNothing() {
        #expect(SeriesVerdictsView.runStatus(hasEnded: nil, nextEpisodeDate: nil) == nil)
    }

    @Test("a confirmed ending leaves the run-status row to the ending verdict")
    func endedSaysNothingHere() {
        #expect(SeriesVerdictsView.runStatus(hasEnded: true, nextEpisodeDate: nil) == nil)
        #expect(SeriesVerdictsView.runStatus(hasEnded: true, nextEpisodeDate: .distantFuture) == nil)
    }

    @Test("no run-status copy ever says the series has ended")
    func neverSaysEnded() {
        let dates: [Date?] = [nil, EpisodeMetric.parseAirDate("2031-03-14")]
        for hasEnded in [Bool?.none, false, true] {
            for date in dates {
                guard let status = SeriesVerdictsView.runStatus(hasEnded: hasEnded, nextEpisodeDate: date) else { continue }
                #expect(!status.title.lowercased().contains("ended"))
                #expect(!status.evidence.lowercased().contains("ended"))
            }
        }
    }

    // MARK: - Seasons not loaded

    @Test("the partial-fetch refusal names the seasons that did not load")
    func seasonsNotLoadedNamesTheGap() {
        #expect(
            SeriesAnalysisSection.seasonsNotLoadedExplanation([3])
                == "We couldn't load season 3, and an analysis without it would be a guess."
        )
        #expect(
            SeriesAnalysisSection.seasonsNotLoadedExplanation([5, 2, 4])
                == "We couldn't load seasons 2, 4 and 5, and an analysis without them would be a guess."
        )
        #expect(SeriesAnalysisSection.seasonsNotLoadedNotice([2, 3]) == "Seasons 2 and 3 couldn't be loaded.")
    }
}
