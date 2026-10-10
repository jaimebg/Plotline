import Foundation
import Testing
@testable import Plotline

@Suite("Discover rotation")
struct DiscoverRotationTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(id: Int, seasons: Int = 3, backdrop: String? = "/b.jpg") -> DatasetEntry {
        let base = ExplorerFixtures.entry(id: id)
        let summaries = (0..<seasons).map {
            SeasonSummary(seasonNumber: $0 + 1, weightedAverage: 8, standardDeviation: 0.2,
                          reliableEpisodeCount: 8, airedEpisodeCount: 8, bestEpisode: nil, worstEpisode: nil)
        }
        let a = base.analysis
        return DatasetEntry(
            tmdbId: id, name: base.name, mediaType: "tv", overview: "", posterPath: "/p.jpg",
            backdropPath: backdrop, voteAverage: 8, genreIds: [18], firstAirDate: "2010-01-01",
            analysis: SeriesAnalysis(
                seasons: summaries, bestSeason: a.bestSeason, worstSeason: a.worstSeason,
                declinePoint: a.declinePoint, declineTest: a.declineTest, consistency: a.consistency,
                standoutHighs: [], standoutLows: [], openingVerdict: a.openingVerdict,
                endingVerdict: a.endingVerdict, score: a.score, isOngoing: a.isOngoing
            ),
            awards: []
        )
    }

    @Test("day zero is the reference day, and days count up from it")
    func dayIndex() {
        #expect(DiscoverRotation.dayIndex(of: date(2026, 1, 1), calendar: Self.calendar) == 0)
        #expect(DiscoverRotation.dayIndex(of: date(2026, 1, 2), calendar: Self.calendar) == 1)
        #expect(DiscoverRotation.dayIndex(of: date(2025, 12, 31), calendar: Self.calendar) == -1)
    }

    @Test("the same series all day")
    func sameDaySameSeries() {
        let entries = [entry(id: 3), entry(id: 5), entry(id: 9)]
        let morning = DiscoverRotation.featured(from: entries, on: date(2026, 3, 4, hour: 0), calendar: Self.calendar)
        let night = DiscoverRotation.featured(from: entries, on: date(2026, 3, 4, hour: 23), calendar: Self.calendar)
        #expect(morning?.tmdbId == night?.tmdbId)
    }

    @Test("one step through the eligible series per day, by id, wrapping")
    func stepsAndWraps() {
        let entries = [entry(id: 9), entry(id: 3), entry(id: 5)]
        let ids = (1...4).map { day in
            DiscoverRotation.featured(from: entries, on: date(2026, 1, day), calendar: Self.calendar)?.tmdbId
        }
        #expect(ids == [3, 5, 9, 3])
    }

    @Test("a day before the reference wraps instead of crashing")
    func dayBeforeReferenceWraps() {
        let entries = [entry(id: 3), entry(id: 5), entry(id: 9)]
        #expect(DiscoverRotation.featured(from: entries, on: date(2025, 12, 31), calendar: Self.calendar)?.tmdbId == 9)
    }

    @Test("too few seasons or no backdrop is never featured")
    func eligibility() {
        let entries = [entry(id: 1, seasons: 2), entry(id: 2, backdrop: nil), entry(id: 3, backdrop: ""), entry(id: 4)]
        let picks = Set((1...10).compactMap { day in
            DiscoverRotation.featured(from: entries, on: date(2026, 1, day), calendar: Self.calendar)?.tmdbId
        })
        #expect(picks == [4])
    }

    @Test("nothing eligible features nothing")
    func emptyFeaturesNothing() {
        #expect(DiscoverRotation.featured(from: [], on: date(2026, 1, 1), calendar: Self.calendar) == nil)
        #expect(DiscoverRotation.featured(from: [entry(id: 1, seasons: 1)], on: date(2026, 1, 1), calendar: Self.calendar) == nil)
    }

    private func list(_ id: String) -> CuratedList { CuratedList(id: id, tmdbIds: [1]) }

    private let genreLists = [
        "never-decline/16", "never-decline/18", "never-decline/35", "never-decline/80",
        "falls-off/18", "perfect-ending/18",
    ]

    @Test("three consecutive genres from the day's starting genre, wrapping")
    func threeGenres() {
        let lists = genreLists.map(list)
        // Genres sorted: 16, 18, 35, 80. Day 3 starts at 80 and wraps.
        let shelves = DiscoverRotation.genreShelves(from: lists, on: date(2026, 1, 4), calendar: Self.calendar)
        #expect(shelves.compactMap { CuratedListID($0.id)?.genreId } == [80, 16, 18])
    }

    @Test("a genre with several shelves rotates through them in the order given")
    func rotatesWithinGenre() {
        // Animation and comedy sit on bases drama does not have, so the
        // distinct-base rule never moves drama off its rotated pick and the
        // rotation shows through unchanged.
        let lists = ["slow-burn/16", "never-decline/18", "falls-off/18", "perfect-ending/18", "rollercoaster/35"]
            .map(list)
        let drama = (1...4).map { day -> String? in
            DiscoverRotation.genreShelves(from: lists, on: date(2026, 1, day), calendar: Self.calendar)
                .first { CuratedListID($0.id)?.genreId == 18 }?.id
        }
        // Drama's lists in input order: never-decline, falls-off, perfect-ending.
        // Drama is genre position 1 of 3, so its index is day + 1: it starts
        // one shelf in and advances one shelf a day.
        #expect(drama == ["falls-off/18", "perfect-ending/18", "never-decline/18", "falls-off/18"])
    }

    @Test("a day's genre shelves come from different base shelves, even when genres have uneven shelf counts")
    func neighboursDiffer() {
        // Five, four and one shelves: with `(day + position) mod count` alone
        // the lone comedy shelf collides with whichever neighbour lands on
        // never-decline. Distinct bases always exist here, since comedy needs
        // only its one and the others have three or more to spare.
        let lists = [
            "never-decline/16", "falls-off/16", "slow-burn/16", "perfect-ending/16", "rollercoaster/16",
            "never-decline/18", "falls-off/18", "slow-burn/18", "perfect-ending/18",
            "never-decline/35",
        ].map(list)
        for day in 1...60 {
            let on = Self.calendar.date(byAdding: .day, value: day - 1, to: date(2026, 1, 1))!
            let shelves = DiscoverRotation.genreShelves(from: lists, on: on, calendar: Self.calendar)
            let picked = shelves.compactMap { CuratedListID($0.id)?.base }
            #expect(picked.count == 3)
            #expect(Set(picked).count == 3, "day \(day): \(shelves.map(\.id))")
        }
    }

    @Test("the first genre shelf avoids the base of the main shelf above it whenever its genre has another")
    func avoidsTheShelfAbove() throws {
        let bases = ["never-decline", "falls-off", "slow-burn", "perfect-ending", "rollercoaster"]
        // War has only the avoided base: it still shows, on that base, rather
        // than being dropped.
        let lists = [16, 18, 35].flatMap { genre in bases.map { list("\($0)/\(genre)") } }
            + [list("rollercoaster/10768")]
        var firstWasForced = false
        for day in 1...60 {
            let on = Self.calendar.date(byAdding: .day, value: day - 1, to: date(2026, 1, 1))!
            let plain = DiscoverRotation.genreShelves(from: lists, on: on, calendar: Self.calendar)
            let shelves = DiscoverRotation.genreShelves(
                from: lists, on: on, calendar: Self.calendar, avoidingBase: "rollercoaster"
            )
            // The genres on screen never change; only the shelf within each.
            #expect(shelves.map { CuratedListID($0.id)?.genreId } == plain.map { CuratedListID($0.id)?.genreId })
            let first = try #require(shelves.first.flatMap { CuratedListID($0.id) })
            if first.genreId == 10768 {
                firstWasForced = true
                #expect(first.base == "rollercoaster")
            } else {
                #expect(first.base != "rollercoaster", "day \(day): \(shelves.map(\.id))")
            }
        }
        #expect(firstWasForced)
    }

    @Test("the avoided base only steers the first slot, so its genre shelves still appear lower down")
    func avoidedBaseStillShowsBelow() {
        let bases = ["never-decline", "falls-off", "slow-burn", "perfect-ending", "rollercoaster"]
        let lists = [16, 18, 35, 80].flatMap { genre in bases.map { list("\($0)/\(genre)") } }
        let lower = (1...40).flatMap { day -> [String] in
            let on = Self.calendar.date(byAdding: .day, value: day - 1, to: date(2026, 1, 1))!
            return DiscoverRotation.genreShelves(
                from: lists, on: on, calendar: Self.calendar, avoidingBase: "rollercoaster"
            ).dropFirst().compactMap { CuratedListID($0.id)?.base }
        }
        #expect(lower.contains("rollercoaster"))
    }

    /// Eight genres, one with four shelves: the shape the shipped data has.
    /// Every base is unique to its genre, so the distinct-base rule never
    /// moves a pick and the rotation itself is what is measured.
    private var eightGenres: [CuratedList] {
        let genres = [16, 18, 35, 80, 9648, 10751, 10759, 10765]
        return genres.flatMap { genre in
            (0..<(genre == 80 ? 4 : 5)).map { list("b\($0)g\(genre)/\(genre)") }
        }
    }

    @Test("a genre advances one shelf each time it appears, whatever the genre count")
    func advancesPerAppearance() {
        let crime = (0..<120).compactMap { offset -> String? in
            let on = Self.calendar.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            return DiscoverRotation.genreShelves(from: eightGenres, on: on, calendar: Self.calendar)
                .first { CuratedListID($0.id)?.genreId == 80 }?.id
        }
        let order = (0..<4).map { "b\($0)g80/80" }
        // Each appearance is the shelf after the previous one, so all four
        // come round in turn instead of the same three.
        for (previous, next) in zip(crime, crime.dropFirst()) {
            let expected = order[(order.firstIndex(of: previous)! + 1) % order.count]
            #expect(next == expected, "\(previous) was followed by \(next)")
        }
        #expect(Set(crime) == Set(order))
    }

    @Test("every shelf of every genre reaches Discover")
    func everyShelfIsReachable() {
        let shown = (0..<120).reduce(into: Set<String>()) { seen, offset in
            let on = Self.calendar.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            seen.formUnion(DiscoverRotation.genreShelves(from: eightGenres, on: on, calendar: Self.calendar).map(\.id))
        }
        #expect(shown == Set(eightGenres.map(\.id)))
    }

    @Test("fewer genres than slots shows each once; none shows none; main and malformed ids are ignored")
    func fewerGenres() {
        let lists = ["never-decline", "falls-off/18", "bad//1", "slow-burn/35"].map(list)
        let shelves = DiscoverRotation.genreShelves(from: lists, on: date(2026, 1, 1), calendar: Self.calendar)
        #expect(Set(shelves.map(\.id)) == ["falls-off/18", "slow-burn/35"])
        #expect(DiscoverRotation.genreShelves(from: [], on: date(2026, 1, 1), calendar: Self.calendar).isEmpty)
    }
}

/// The rotation over the lists that actually ship. Main-actor isolated because
/// `DatasetStore` is.
@MainActor
@Suite("Discover rotation over the shipped dataset")
struct ShippedDiscoverRotationTests {
    @Test("a year of genre shelves never repeats a base within a day, nor the main shelf above")
    func aYearOfShippedGenreShelves() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let store = DatasetStore.shared
        let avoided = try #require(store.mainLists.last.flatMap { CuratedListID($0.id)?.base })
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))

        // The shipped genres hold 5, 5, 5, 4, 4, 1, 5 and 5 shelves. Family's
        // one shelf is perfect-ending, and no genre has the avoided base as
        // its only shelf, so the shipped data satisfies both rules on every
        // day: no exception is allowed.
        for offset in 0..<365 {
            let day = try #require(calendar.date(byAdding: .day, value: offset, to: start))
            let shelves = DiscoverRotation.genreShelves(
                from: store.genreLists, on: day, calendar: calendar, avoidingBase: avoided
            )
            let bases = shelves.compactMap { CuratedListID($0.id)?.base }
            #expect(shelves.count == DiscoverRotation.genreShelfCount, "day \(offset)")
            #expect(Set(bases).count == bases.count, "day \(offset): \(shelves.map(\.id))")
            #expect(bases.first != avoided, "day \(offset): \(shelves.map(\.id)) repeats \(avoided)")
        }
    }

    @Test("every shipped genre shelf reaches Discover within a year")
    func everyShippedGenreShelfAppears() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let store = DatasetStore.shared
        let avoided = try #require(store.mainLists.last.flatMap { CuratedListID($0.id)?.base })
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))

        var shown = Set<String>()
        for offset in 0..<365 {
            let day = try #require(calendar.date(byAdding: .day, value: offset, to: start))
            shown.formUnion(
                DiscoverRotation.genreShelves(from: store.genreLists, on: day, calendar: calendar, avoidingBase: avoided)
                    .map(\.id)
            )
        }
        // A genre list that never comes round is a shelf nobody can reach:
        // genre lists surface nowhere else.
        #expect(Set(store.genreLists.map(\.id)).subtracting(shown).isEmpty, "never shown: \(Set(store.genreLists.map(\.id)).subtracting(shown).sorted())")
    }
}
