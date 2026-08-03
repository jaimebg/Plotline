import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("Dataset builder")
struct DatasetBuilderTests {
    private func entry(
        id: Int,
        name: String,
        ratings: [[Double]],
        awards: [String] = []
    ) -> DatasetEntry? {
        var episodes: [EpisodeMetric] = []
        for (index, season) in ratings.enumerated() {
            for (number, rating) in season.enumerated() {
                episodes.append(
                    EpisodeMetric(
                        episodeNumber: number + 1,
                        seasonNumber: index + 1,
                        title: "S\(index + 1)E\(number + 1)",
                        rating: rating,
                        voteCount: 100,
                        airDate: "2010-01-01"
                    )
                )
            }
        }

        let reference = Date(timeIntervalSince1970: 1_577_836_800)
        guard case .analyzed(let analysis) = SeriesAnalysisEngine.analyze(
            episodes: episodes, hasEnded: true, asOf: reference
        ) else { return nil }

        return DatasetEntry(
            tmdbId: id,
            name: name,
            posterPath: nil,
            analysis: analysis,
            awards: awards
        )
    }

    @Test("collects series that never decline")
    func buildsNeverDeclineList() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5], [8.5, 8.6, 8.5, 8.6], [8.6, 8.5, 8.6, 8.5]]))
        let faller = try #require(entry(id: 2, name: "Faller", ratings: [[8.8, 8.9, 8.7, 8.8], [8.9, 8.8, 8.9, 8.8], [7.2, 7.1, 7.3, 7.2], [7.0, 7.1, 6.9, 7.0]]))

        let dataset = DatasetBuilder.build(entries: [steady, faller])
        let list = try #require(dataset.lists.first { $0.id == "never-decline" })
        #expect(list.tmdbIds == [1])
    }

    @Test("collects series that fall off")
    func buildsFallsOffList() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5], [8.5, 8.6, 8.5, 8.6], [8.6, 8.5, 8.6, 8.5]]))
        let faller = try #require(entry(id: 2, name: "Faller", ratings: [[8.8, 8.9, 8.7, 8.8], [8.9, 8.8, 8.9, 8.8], [7.2, 7.1, 7.3, 7.2], [7.0, 7.1, 6.9, 7.0]]))

        let dataset = DatasetBuilder.build(entries: [steady, faller])
        let list = try #require(dataset.lists.first { $0.id == "falls-off" })
        #expect(list.tmdbIds == [2])
    }

    @Test("every curated list carries a title and is never emitted empty")
    func listsAreWellFormed() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5], [8.5, 8.6, 8.5, 8.6], [8.6, 8.5, 8.6, 8.5]]))
        let dataset = DatasetBuilder.build(entries: [steady])

        for list in dataset.lists {
            #expect(!list.title.isEmpty)
            #expect(!list.tmdbIds.isEmpty)
        }
    }

    @Test("entries come back sorted by id so regeneration is reproducible")
    func sortsEntries() throws {
        let a = try #require(entry(id: 9, name: "Nine", ratings: [[8.5, 8.6, 8.4, 8.5]]))
        let b = try #require(entry(id: 2, name: "Two", ratings: [[8.5, 8.6, 8.4, 8.5]]))

        #expect(DatasetBuilder.build(entries: [a, b]).entries.map(\.tmdbId) == [2, 9])
    }

    @Test("the dataset round-trips through Codable")
    func roundTrips() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5]], awards: ["Peabody Awards"]))
        let dataset = DatasetBuilder.build(entries: [steady])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(dataset)
        let decoded = try JSONDecoder().decode(PlotlineDataset.self, from: data)

        #expect(decoded == dataset)
        #expect(decoded.entries[0].awards == ["Peabody Awards"])
    }
}
