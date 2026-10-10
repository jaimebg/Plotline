import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("Seed selection")
struct SeedSelectorTests {
    private func c(_ id: Int, _ genres: [Int] = [18], name: String? = nil) -> SeedCandidate {
        SeedCandidate(id: id, name: name ?? "Series \(id)", genreIds: genres)
    }

    @Test("talk, news and reality are never selected, from either source")
    func excludesGenres() {
        let selection = SeedSelector.select(
            handPicked: [],
            excluded: [],
            popular: [c(1, [10767]), c(2, [10763, 18]), c(3, [10764]), c(4, [18])],
            byGenre: [35: [c(5, [35, 10764]), c(6, [35])]],
            target: 1_000,
            genreFloor: 2
        )
        #expect(selection.seeds.map(\.id) == [4, 6])
    }

    @Test("hand-picked and excluded ids are never selected again")
    func skipsCuratedIds() {
        let selection = SeedSelector.select(
            handPicked: [1], excluded: [2], popular: [c(1), c(2), c(3)], byGenre: [:], target: 1_000, genreFloor: 0
        )
        #expect(selection.seeds.map(\.id) == [3])
    }

    @Test("the popular fill stops at the target, counting the hand-picked")
    func stopsAtTarget() {
        let selection = SeedSelector.select(
            handPicked: [1, 2], excluded: [], popular: (10...19).map { c($0) }, byGenre: [:], target: 5, genreFloor: 0
        )
        #expect(selection.seeds.map(\.id) == [10, 11, 12])
    }

    @Test("a series listed twice is selected once")
    func deduplicates() {
        let selection = SeedSelector.select(
            handPicked: [], excluded: [], popular: [c(10), c(10), c(11)], byGenre: [:], target: 1_000, genreFloor: 0
        )
        #expect(selection.seeds.map(\.id) == [10, 11])
    }

    @Test("a thin genre is topped up to its floor and no further")
    func topsUpToFloor() {
        let selection = SeedSelector.select(
            handPicked: [],
            excluded: [],
            popular: [c(1), c(2), c(3)],
            byGenre: [35: (100...109).map { c($0, [35]) }],
            target: 1_000,
            genreFloor: 4
        )
        let comedies = selection.seeds.filter { $0.genreIds.contains(35) }.map(\.id)
        #expect(comedies == [100, 101, 102, 103])
        #expect(selection.shortGenres[35] == nil)
    }

    @Test("a genre TMDB cannot fill is reported with its count, not fatal")
    func reportsUnfillableGenre() {
        let selection = SeedSelector.select(
            handPicked: [], excluded: [], popular: [], byGenre: [37: [c(200, [37]), c(201, [37])]],
            target: 1_000, genreFloor: 4
        )
        #expect(selection.shortGenres[37] == 2)
        #expect(selection.seeds.map(\.id) == [200, 201])
    }

    @Test("a top-up counts toward every floored genre it carries")
    func topUpCountsForEveryGenre() {
        // 35 is topped up before 18 (`flooredGenres` order), and the comedy
        // that is also a drama fills 18's floor of one on the way.
        let selection = SeedSelector.select(
            handPicked: [], excluded: [], popular: [],
            byGenre: [35: [c(100, [35, 18])], 18: [c(101, [18])]],
            target: 1_000, genreFloor: 1
        )
        #expect(selection.seeds.contains { $0.id == 100 })
        #expect(!selection.seeds.contains { $0.id == 101 })
    }

    @Test("the rendered file lists every id, in order, with a one-line name")
    func rendersSeedList() {
        let source = SeedSelector.render([c(1396, name: "Breaking Bad"), c(7, name: "Two\nLines")])

        #expect(source.contains("        1396,  // Breaking Bad\n"))
        #expect(source.contains("        7,  // Two Lines\n"))
        #expect(source.contains("static let discoveredIds: [Int] = ["))
        #expect(source.contains("static var seriesIds: [Int] { SeedCuration.handPickedIds + discoveredIds }"))
        #expect(source.hasSuffix("}\n"))

        let ids = source.split(separator: "\n").compactMap { line -> Int? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let comma = trimmed.firstIndex(of: ",") else { return nil }
            return Int(trimmed[..<comma])
        }
        #expect(ids == [1396, 7])
    }

    @Test("the committed seed list starts with the hand-picked ids and holds no excluded one")
    func committedSeedListIsCurated() {
        #expect(Array(SeedList.seriesIds.prefix(SeedCuration.handPickedIds.count)) == SeedCuration.handPickedIds)
        #expect(SeedCuration.excludedIds.isDisjoint(with: SeedList.seriesIds))
    }
}
