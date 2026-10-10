import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("See all ordering")
struct CuratedListViewTests {
    private func entry(_ id: Int, _ name: String, score: Int) -> DatasetEntry {
        ExplorerFixtures.entry(id: id, name: name, score: PlotlineScore(value: score, level: score, consistency: score, trajectory: 50))
    }

    @Test("best Plotline Score first, ties by name")
    func ordering() {
        let ordered = CuratedListView.ordered([
            entry(1, "Beta", score: 70), entry(2, "Alpha", score: 70), entry(3, "Gamma", score: 90),
        ])
        #expect(ordered.map(\.tmdbId) == [3, 2, 1])
    }
}
