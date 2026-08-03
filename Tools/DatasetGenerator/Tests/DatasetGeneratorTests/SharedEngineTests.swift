import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("Shared engine")
struct SharedEngineTests {
    /// The point of this test is not the analysis — the app's own suite covers
    /// that exhaustively. It is that the engine links and runs from outside the
    /// app target at all, which is the whole premise of sharing by path.
    @Test("the app's analysis engine runs inside the generator package")
    func engineRunsOutsideTheApp() {
        let episodes = (1...6).map { number in
            EpisodeMetric(
                episodeNumber: number,
                seasonNumber: 1,
                title: "S1E\(number)",
                rating: 8.0 + Double(number) * 0.1,
                voteCount: 100,
                airDate: "2010-01-01"
            )
        }

        let reference = Date(timeIntervalSince1970: 1_577_836_800) // 2020-01-01 UTC
        let result = SeriesAnalysisEngine.analyze(episodes: episodes, asOf: reference)

        guard case .analyzed(let analysis) = result else {
            Issue.record("expected .analyzed, got \(result)")
            return
        }
        #expect(analysis.seasons.count == 1)
        #expect(analysis.score.value > 0)
    }
}
