import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("DatasetStore")
struct DatasetStoreTests {
    @Test("the bundled dataset loads")
    func loadsBundledDataset() {
        #expect(DatasetStore.shared.load() != nil)
    }

    @Test("the dataset ships a usable number of series")
    func shipsEnoughSeries() {
        // The whole point of this dataset is that the app is not empty on a
        // clean install, so a handful of entries would defeat it.
        #expect(DatasetStore.shared.entries.count >= 50)
    }

    @Test("every entry carries what a MediaItem needs")
    func entriesAreComplete() {
        for entry in DatasetStore.shared.entries {
            #expect(!entry.name.isEmpty)
            #expect(entry.posterPath != nil)
            #expect(!entry.genreIds.isEmpty)
        }
    }

    @Test("curated lists resolve to real entries")
    func listsResolve() {
        let store = DatasetStore.shared
        #expect(!store.lists.isEmpty)

        for list in store.lists {
            let resolved = store.entries(for: list)
            #expect(resolved.count == list.tmdbIds.count)
        }
    }

    @Test("an entry can be found by its TMDB id")
    func findsEntryById() throws {
        let first = try #require(DatasetStore.shared.entries.first)
        #expect(DatasetStore.shared.entry(forTMDBId: first.tmdbId)?.name == first.name)
    }

    @Test("an unknown id returns nil rather than crashing")
    func unknownIdIsNil() {
        #expect(DatasetStore.shared.entry(forTMDBId: -1) == nil)
    }

    @Test("entry ids are unique, so the lookup index cannot lose entries")
    func entryIdsAreUnique() {
        let ids = DatasetStore.shared.entries.map(\.tmdbId)
        #expect(Set(ids).count == ids.count)
    }
}
