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
        let lists = genreLists.map(list)
        // count: 4 so drama is on screen every day; with three slots and four
        // genres it would drop out on day 2.
        let drama = (1...4).map { day -> String? in
            DiscoverRotation.genreShelves(from: lists, on: date(2026, 1, day), calendar: Self.calendar, count: 4)
                .first { CuratedListID($0.id)?.genreId == 18 }?.id
        }
        // Drama's lists in input order: never-decline, falls-off, perfect-ending.
        #expect(drama == ["never-decline/18", "falls-off/18", "perfect-ending/18", "never-decline/18"])
    }

    @Test("fewer genres than slots shows each once; none shows none; main and malformed ids are ignored")
    func fewerGenres() {
        let lists = ["never-decline", "falls-off/18", "bad//1", "slow-burn/35"].map(list)
        let shelves = DiscoverRotation.genreShelves(from: lists, on: date(2026, 1, 1), calendar: Self.calendar)
        #expect(Set(shelves.map(\.id)) == ["falls-off/18", "slow-burn/35"])
        #expect(DiscoverRotation.genreShelves(from: [], on: date(2026, 1, 1), calendar: Self.calendar).isEmpty)
    }
}
