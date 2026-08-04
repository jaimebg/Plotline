import Foundation
import Testing
@testable import Plotline

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
}
