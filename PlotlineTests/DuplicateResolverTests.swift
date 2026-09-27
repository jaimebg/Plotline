import Foundation
import Testing
@testable import Plotline

@Suite("Duplicate resolution")
struct DuplicateResolverTests {
    private struct Record: Equatable {
        let name: String
        let tmdbId: Int
        let addedAt: Date
    }

    private func day(_ n: Double) -> Date {
        Date(timeIntervalSince1970: n * 86_400)
    }

    private func groups(_ records: [Record]) -> [DuplicateResolver.Group<Record>] {
        DuplicateResolver.group(records, id: \.tmdbId, addedAt: \.addedAt)
    }

    /// Every device must pick the same survivor, or two devices delete each
    /// other's copy. The earliest-added record is that shared choice, whatever
    /// order the fetch happened to return.
    @Test("the earliest-added copy is kept, regardless of input order")
    func keepsEarliest() {
        let early = Record(name: "early", tmdbId: 1, addedAt: day(1))
        let late = Record(name: "late", tmdbId: 1, addedAt: day(5))

        for input in [[early, late], [late, early]] {
            let result = groups(input)
            #expect(result.count == 1)
            #expect(result.first?.keeper == early)
            #expect(result.first?.duplicates == [late])
        }
    }

    @Test("groups come back newest first, the order the lists show")
    func displayOrder() {
        let a = Record(name: "a", tmdbId: 1, addedAt: day(1))
        let b = Record(name: "b", tmdbId: 2, addedAt: day(3))
        let c = Record(name: "c", tmdbId: 3, addedAt: day(2))
        let bDuplicate = Record(name: "b2", tmdbId: 2, addedAt: day(9))

        let keepers = groups([a, bDuplicate, b, c]).map(\.keeper.name)
        // b's group sorts by its keeper (day 3), not by its newest copy (day 9).
        #expect(keepers == ["b", "c", "a"])
    }

    @Test("equal dates keep input order, so the choice is still deterministic")
    func tiesKeepInputOrder() {
        let first = Record(name: "first", tmdbId: 1, addedAt: day(1))
        let second = Record(name: "second", tmdbId: 1, addedAt: day(1))

        #expect(groups([first, second]).first?.keeper == first)
    }

    @Test("records without duplicates pass through as single groups")
    func uniqueRecords() {
        let records = (1...4).map { Record(name: "\($0)", tmdbId: $0, addedAt: day(Double($0))) }
        let result = groups(records)
        #expect(result.count == 4)
        #expect(result.allSatisfy { $0.duplicates.isEmpty })
    }

    /// The bug: keeping the newest copy dropped a "watched" status set on the
    /// other device. Whichever copy survives, it must carry the furthest state.
    @Test("watched on any copy wins over want to watch")
    func watchedWins() {
        #expect(DuplicateResolver.mostAdvancedWatchStatus(["want_to_watch", "watched"]) == "watched")
        #expect(DuplicateResolver.mostAdvancedWatchStatus(["watched", "want_to_watch"]) == "watched")
        #expect(DuplicateResolver.mostAdvancedWatchStatus(["want_to_watch", "want_to_watch"]) == "want_to_watch")
    }

    @Test("an unknown status never beats a known one")
    func unknownStatus() {
        #expect(DuplicateResolver.mostAdvancedWatchStatus(["something_new", "want_to_watch"]) == "want_to_watch")
        #expect(DuplicateResolver.mostAdvancedWatchStatus([]) == "want_to_watch")
    }

    @Test("missing metadata is filled from a later copy, the keeper's wins otherwise")
    func firstPresent() {
        #expect(DuplicateResolver.firstPresent([nil, "/b.jpg"]) == "/b.jpg")
        #expect(DuplicateResolver.firstPresent(["", "/b.jpg"]) == "/b.jpg")
        #expect(DuplicateResolver.firstPresent(["/a.jpg", "/b.jpg"]) == "/a.jpg")
        #expect(DuplicateResolver.firstPresent([nil, nil]) == nil)
    }
}
