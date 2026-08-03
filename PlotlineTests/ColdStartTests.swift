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

    @Test("all five shelves ship")
    func allShelvesShip() {
        // The generator drops a list entirely when it falls below its minimum
        // size, and the other assertions here only iterate the lists that are
        // present — so a vanished shelf is invisible to every one of them.
        #expect(DatasetStore.shared.lists.count == 5)
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
        // Asserts against the same DatasetStore.topRated that
        // SuggestionsEmptyState.suggestions calls, rather than a hand-copied
        // reimplementation of the sort — so this is a test of what the view
        // actually shows, not of a duplicate that can drift from it.
        // `posterPath != nil` is not re-checked here: entriesAreComplete
        // already asserts it across every entry in the dataset.
        let ranked = DatasetStore.shared.topRated(limit: 12)
        #expect(ranked.count == 12)

        // .prefix(12) yields twelve items whichever way the sort runs, so the
        // count alone cannot see an inverted comparator. Assert the ordering
        // the shelf's heading depends on.
        let scores = ranked.map(\.analysis.score.value)
        #expect(scores == scores.sorted(by: >))
    }

    @Test("the shelves carry enough titles between them to fill a screen")
    func shelvesCarryEnoughTitles() {
        // The dataset ships 72 across five shelves. A floor near that catches
        // the loss of a whole shelf; a floor far below it catches nothing,
        // which is worse than no test because it reads as coverage.
        let total = DatasetStore.shared.lists.reduce(0) { $0 + $1.tmdbIds.count }
        #expect(total >= 60, "only \(total) titles across all shelves — a shelf may have been lost")
    }
}
