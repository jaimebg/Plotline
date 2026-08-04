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
}
