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

@MainActor
@Suite("Dataset presentation")
struct DatasetPresentationTests {
    @Test("every shipped list has English copy")
    func everyListHasCopy() {
        // A shelf with no title cannot be rendered, so a dataset id with no
        // copy is a shipping defect, not a fallback case.
        for list in DatasetStore.shared.lists {
            #expect(CuratedListCopy.title(for: list.id) != nil, "no title for \(list.id)")
            #expect(CuratedListCopy.subtitle(for: list.id) != nil, "no subtitle for \(list.id)")
        }
    }

    @Test("an unknown list id has no copy")
    func unknownIdHasNoCopy() {
        #expect(CuratedListCopy.title(for: "not-a-list") == nil)
    }

    @Test("an entry converts to a MediaItem the existing views can render")
    func convertsToMediaItem() throws {
        let entry = try #require(DatasetStore.shared.entries.first)
        let item = entry.asMediaItem

        #expect(item.id == entry.tmdbId)
        #expect(item.displayTitle == entry.name)
        #expect(item.isTVSeries)
        #expect(item.posterPath == entry.posterPath)
        #expect(item.voteAverage == entry.voteAverage)
    }

    @Test("converted items carry the genres the taste profile needs")
    func conversionKeepsGenres() throws {
        let entry = try #require(DatasetStore.shared.entries.first { !$0.genreIds.isEmpty })
        #expect(entry.asMediaItem.genreIds == entry.genreIds)
    }

    @Test("the falls-off subtitle claims only what the analysis proves")
    func fallsOffCopyDoesNotOverclaim() {
        // The predicate establishes a relative drop that never recovers. It
        // says nothing about how good the show was beforehand, so the copy
        // must not either.
        #expect(CuratedListCopy.subtitle(for: "falls-off") == "The numbers show a real drop-off it never comes back from")
    }
}
