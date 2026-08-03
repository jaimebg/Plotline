import Foundation
import Testing
@testable import DatasetGeneratorCore

@Suite("Dataset builder")
struct DatasetBuilderTests {
    /// Holds its level for three seasons and ends at its peak.
    private static let steadyRatings = [[8.5, 8.6, 8.4, 8.5], [8.5, 8.6, 8.5, 8.6], [8.6, 8.5, 8.6, 8.5]]

    /// Falls off after season two and never comes back.
    private static let fallerRatings = [[8.8, 8.9, 8.7, 8.8], [8.9, 8.8, 8.9, 8.8], [7.2, 7.1, 7.3, 7.2], [7.0, 7.1, 6.9, 7.0]]

    /// The shape MUST FIX 2 was about: no decline, steady episode-to-episode,
    /// a worst season that is not the last — and a final season far enough
    /// below the peak that the analysis itself says `fadesOut`.
    private static let fadesOutRatings = [
        [8.6, 8.6, 8.6, 8.6],
        [7.8, 7.8, 7.8, 7.8],
        [8.6, 8.6, 8.6, 8.6],
        [8.0, 8.0, 8.0, 8.0]
    ]

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
            mediaType: "tv",
            overview: "An overview.",
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 8.4,
            genreIds: [18],
            firstAirDate: "2010-01-01",
            analysis: analysis,
            awards: awards
        )
    }

    /// `minimumListSize` copies of a shape, so a list built from them ships.
    private func entries(ids: [Int], ratings: [[Double]]) throws -> [DatasetEntry] {
        try ids.map { try #require(entry(id: $0, name: "Series \($0)", ratings: ratings)) }
    }

    @Test("collects series that never decline")
    func buildsNeverDeclineList() throws {
        let steady = try entries(ids: [1, 2, 3], ratings: Self.steadyRatings)
        let fallers = try entries(ids: [4, 5, 6], ratings: Self.fallerRatings)

        let dataset = DatasetBuilder.build(entries: steady + fallers)
        let list = try #require(dataset.lists.first { $0.id == "never-decline" })
        #expect(list.tmdbIds == [1, 2, 3])
    }

    @Test("collects series that fall off")
    func buildsFallsOffList() throws {
        let steady = try entries(ids: [1, 2, 3], ratings: Self.steadyRatings)
        let fallers = try entries(ids: [4, 5, 6], ratings: Self.fallerRatings)

        let dataset = DatasetBuilder.build(entries: steady + fallers)
        let list = try #require(dataset.lists.first { $0.id == "falls-off" })
        #expect(list.tmdbIds == [4, 5, 6])
    }

    // MARK: - The never-decline invariant

    @Test("a series whose own verdict is fadesOut never reaches the never-decline list")
    func neverDeclineExcludesFadesOut() throws {
        let fading = try entries(ids: [1, 2, 3], ratings: Self.fadesOutRatings)

        // The fixture has to actually be the awkward case, or the test passes
        // for the wrong reason: no decline to disqualify it, steady enough to
        // clear the consistency bar, and still fading out at the end.
        for candidate in fading {
            #expect(candidate.analysis.declinePoint == nil)
            #expect(candidate.analysis.endingVerdict?.kind == .fadesOut)
            #expect(
                candidate.analysis.consistency.rating == .steady
                    || candidate.analysis.consistency.rating == .verySteady
            )
        }

        let dataset = DatasetBuilder.build(entries: fading)
        #expect(dataset.lists.first { $0.id == "never-decline" } == nil)
    }

    @Test("no list ever contradicts the analysis behind its own members")
    func listsAgreeWithTheirEntries() throws {
        let mixed = try entries(ids: [1, 2, 3], ratings: Self.steadyRatings)
            + entries(ids: [4, 5, 6], ratings: Self.fallerRatings)
            + entries(ids: [7, 8, 9], ratings: Self.fadesOutRatings)

        let dataset = DatasetBuilder.build(entries: mixed)
        let byId = Dictionary(uniqueKeysWithValues: dataset.entries.map { ($0.tmdbId, $0) })

        for list in dataset.lists {
            for id in list.tmdbIds {
                let analysis = try #require(byId[id]).analysis
                switch list.id {
                case "never-decline":
                    #expect(analysis.declinePoint == nil)
                    #expect(analysis.endingVerdict?.kind != .fadesOut)
                    #expect(analysis.seasons.count >= 3)
                    #expect(analysis.worstSeason != analysis.seasons.last?.seasonNumber)
                case "falls-off":
                    #expect(analysis.declinePoint != nil)
                    #expect(analysis.endingVerdict?.kind != .endsStrong)
                case "slow-burn":
                    #expect(analysis.openingVerdict?.kind == .slowStart)
                    #expect(analysis.openingVerdict?.improvesAtSeason != nil)
                    #expect(analysis.declinePoint == nil)
                case "perfect-ending":
                    #expect(analysis.endingVerdict?.kind == .endsStrong)
                    #expect(analysis.declinePoint == nil)
                case "rollercoaster":
                    #expect(analysis.consistency.rating == .rollercoaster)
                default:
                    Issue.record("unknown list id \(list.id)")
                }
            }
        }
    }

    // MARK: - Shape

    @Test("a list is never emitted below the minimum size")
    func dropsUndersizedLists() throws {
        let two = try entries(ids: [1, 2], ratings: Self.steadyRatings)
        #expect(DatasetBuilder.build(entries: two).lists.isEmpty)

        let three = try entries(ids: [1, 2, 3], ratings: Self.steadyRatings)
        #expect(DatasetBuilder.build(entries: three).lists.isEmpty == false)
    }

    @Test("every curated list carries members and no user-facing copy")
    func listsAreWellFormed() throws {
        let steady = try entries(ids: [1, 2, 3], ratings: Self.steadyRatings)
        let dataset = DatasetBuilder.build(entries: steady)

        #expect(dataset.lists.isEmpty == false)
        for list in dataset.lists {
            #expect(list.tmdbIds.count >= DatasetBuilder.minimumListSize)
            #expect(!list.id.isEmpty)
        }

        // The app owns the copy. A title or subtitle encoded here would be a
        // string the app cannot translate or restyle — and the last one shipped
        // in the wrong language entirely.
        let encoded = try #require(String(data: try JSONEncoder().encode(dataset.lists), encoding: .utf8))
        #expect(!encoded.contains("title"))
        #expect(!encoded.contains("subtitle"))
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

    @Test("an entry carries everything an offline favourite needs")
    func entriesCarryMediaItemFields() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5]]))
        let dataset = DatasetBuilder.build(entries: [steady])

        let data = try JSONEncoder().encode(dataset)
        let decoded = try JSONDecoder().decode(PlotlineDataset.self, from: data).entries[0]

        #expect(decoded.mediaType == "tv")
        #expect(decoded.overview == "An overview.")
        #expect(decoded.voteAverage == 8.4)
        #expect(decoded.genreIds == [18])
        #expect(decoded.firstAirDate == "2010-01-01")
    }

    @Test("a dataset with skipped entries round-trips through Codable")
    func roundTripsWithSkipped() throws {
        let steady = try #require(entry(id: 1, name: "Steady", ratings: [[8.5, 8.6, 8.4, 8.5]]))
        let skipped = [
            SkippedSeries(
                tmdbId: 4614,
                name: "NCIS",
                kind: InsufficientDataReason.tooFewReliableEpisodes.rawValue,
                detail: nil
            ),
            SkippedSeries(tmdbId: 999, name: nil, kind: SkippedSeries.fetchFailedKind, detail: "HTTP 500")
        ]
        let dataset = DatasetBuilder.build(entries: [steady], skipped: skipped)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(dataset)
        let decoded = try JSONDecoder().decode(PlotlineDataset.self, from: data)

        #expect(decoded == dataset)
        #expect(decoded.skipped.count == 2)
        #expect(decoded.skipped.first { $0.tmdbId == 999 }?.name == nil)
        #expect(decoded.skipped.first { $0.tmdbId == 999 }?.detail == "HTTP 500")
    }

    @Test("a skip reason is a fixed category the app can switch on")
    func skipKindsAreFixedCategories() throws {
        // Spelled out rather than derived, so adding a case to the engine's
        // reasons is a deliberate edit to the app's contract, not a silent one.
        let known: Set<String> = [
            InsufficientDataReason.noAiredEpisodes.rawValue,
            InsufficientDataReason.noReliableEpisodes.rawValue,
            InsufficientDataReason.tooFewReliableEpisodes.rawValue,
            InsufficientDataReason.notEnoughEpisodesToAnalyse.rawValue,
            SkippedSeries.fetchFailedKind
        ]

        let skipped = [
            SkippedSeries(tmdbId: 1, name: "A", kind: InsufficientDataReason.noAiredEpisodes.rawValue, detail: nil),
            SkippedSeries(tmdbId: 2, name: nil, kind: SkippedSeries.fetchFailedKind, detail: "HTTP 429")
        ]

        for entry in DatasetBuilder.build(entries: [], skipped: skipped).skipped {
            #expect(known.contains(entry.kind))
        }
    }

    @Test("skipped series come back sorted by id so regeneration is reproducible")
    func sortsSkipped() throws {
        let later = SkippedSeries(tmdbId: 42, name: "Later", kind: SkippedSeries.fetchFailedKind, detail: nil)
        let earlier = SkippedSeries(
            tmdbId: 7,
            name: "Earlier",
            kind: InsufficientDataReason.tooFewReliableEpisodes.rawValue,
            detail: nil
        )

        let dataset = DatasetBuilder.build(entries: [], skipped: [later, earlier])
        #expect(dataset.skipped.map(\.tmdbId) == [7, 42])
    }
}
