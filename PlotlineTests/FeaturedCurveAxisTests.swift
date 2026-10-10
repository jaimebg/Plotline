import Foundation
import Testing
@testable import Plotline

/// Which seasons the featured card's curve labels. At iPhone SE content width
/// (about 311pt) twelve labels already lose the last one, twenty collide and
/// thirty-seven are unreadable, so a long run labels a sample.
@MainActor
@Suite("Featured curve axis")
struct FeaturedCurveAxisTests {
    @Test("first and last always labelled, all of a short run, at most seven of a long one, in order",
          arguments: [1, 2, 6, 8, 9, 12, 20, 37])
    func labelledIndices(count: Int) {
        let labelled = FeaturedSeriesCard.labelledIndices(count: count)
        #expect(labelled.first == 0)
        #expect(labelled.last == count - 1)
        #expect(labelled.count <= (count <= 8 ? count : 7))
        #expect(zip(labelled, labelled.dropFirst()).allSatisfy { $0 < $1 })
        if count <= 8 {
            #expect(labelled == Array(0..<count))
        } else {
            // Every k-th point, k = ceil(count / 6), and no two labels closer
            // than k points: the stride point next to the last gives way.
            let stride = (count + 5) / 6
            #expect(zip(labelled, labelled.dropFirst()).allSatisfy { $1 - $0 >= stride })
        }
    }

    @Test("long runs sample every k-th season and keep the last")
    func longRuns() {
        #expect(FeaturedSeriesCard.labelledIndices(count: 9) == [0, 2, 4, 6, 8])
        #expect(FeaturedSeriesCard.labelledIndices(count: 12) == [0, 2, 4, 6, 8, 11])
        #expect(FeaturedSeriesCard.labelledIndices(count: 20) == [0, 4, 8, 12, 19])
        #expect(FeaturedSeriesCard.labelledIndices(count: 37) == [0, 7, 14, 21, 28, 36])
    }

    @Test("no points, no labels")
    func empty() {
        #expect(FeaturedSeriesCard.labelledIndices(count: 0).isEmpty)
    }
}
