import Foundation
import Testing
@testable import Plotline

/// Guards the defect that got the app rejected under Guideline 4.2.
///
/// App Review evaluates a clean install. The Stats tab wrapped everything —
/// including Compare, Career Profiles and Trends, none of which need user data
/// — in a check for saved favorites, so the reviewer saw an empty screen and
/// concluded the app had nothing in it. These assert the conditions that make
/// a first launch non-empty.
@MainActor
@Suite("Cold start")
struct ColdStartTests {
    @Test("curated content is available with no user data and no network")
    func curatedContentExistsOnAFreshInstall() {
        let store = DatasetStore.shared

        #expect(!store.entries.isEmpty)
        #expect(!store.lists.isEmpty)
    }

    @Test("every shelf that ships is renderable")
    func everyShelfIsRenderable() {
        let store = DatasetStore.shared

        for list in store.lists {
            // A shelf needs copy, and members that resolve, or it renders as
            // nothing — which is the emptiness this whole effort removes.
            #expect(CuratedListCopy.title(for: list.id) != nil, "\(list.id) has no title")
            #expect(!store.entries(for: list).isEmpty, "\(list.id) resolves to nothing")
        }
    }

    @Test("suggestions for the empty Favorites and Watchlist screens exist")
    func suggestionsExist() {
        let ranked = DatasetStore.shared.entries
            .sorted { $0.analysis.score.value > $1.analysis.score.value }
            .prefix(12)

        #expect(ranked.count == 12)
        #expect(ranked.allSatisfy { $0.posterPath != nil })
    }

    @Test("the shelves carry enough titles between them to fill a screen")
    func shelvesCarryEnoughTitles() {
        let total = DatasetStore.shared.lists.reduce(0) { $0 + $1.tmdbIds.count }
        #expect(total >= 40, "only \(total) titles across all shelves")
    }
}
