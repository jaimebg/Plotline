import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("Standout episode copy")
struct StandoutCopyTests {
    /// The engine measures distance from a season's own average and nothing
    /// else. It never establishes that an episode is poor in absolute terms,
    /// so the heading must not advise anyone to skip it.
    @Test("the weak group gives no skipping advice")
    func weakGroupDoesNotAdviseSkipping() {
        let title = StandoutEpisodesView.weakestTitle.lowercased()

        #expect(!title.contains("skip"))
        #expect(!title.contains("miss out"))
        #expect(!title.contains("avoid"))
    }

    /// The fact that makes the point above concrete rather than pedantic: in
    /// the data the app actually ships, episodes flagged as far below their own
    /// season still rate well on any absolute scale. Breaking Bad's weakest
    /// season-5 hours sit above 8.
    @Test("an episode far below its season can still rate above 8")
    func relativeWeaknessIsNotAbsoluteWeakness() throws {
        let highestWeakRating = DatasetStore.shared.entries
            .flatMap { $0.analysis.skippableEpisodes }
            .map(\.rating)
            .max()

        let best = try #require(highestWeakRating, "the bundled dataset should flag some weak episodes")
        #expect(best > 8.0, "a 'weak' episode rating \(best) is not one anyone should be told to skip")
    }
}
