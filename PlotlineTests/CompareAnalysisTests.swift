import Foundation
import Testing
@testable import Plotline

/// Compare's Plotline Analysis section: how a slot's analysis is seeded and
/// replaced, which values may be emphasised, and what the copy is allowed to
/// claim.
@MainActor
@Suite("Compare analysis")
struct CompareAnalysisTests {
    /// Breaking Bad — in the bundled dataset.
    private let bundledSeriesId = 1396

    private func bySeason(_ seasons: [Int], ratings: [Double] = [7.0, 7.1, 7.2, 7.0, 7.1, 7.2]) -> [Int: [EpisodeMetric]] {
        Dictionary(uniqueKeysWithValues: seasons.map { ($0, EpisodeFixtures.season($0, ratings: ratings)) })
    }

    private func grouped(_ episodes: [EpisodeMetric]) -> [Int: [EpisodeMetric]] {
        Dictionary(grouping: episodes, by: \.seasonNumber)
    }

    private func fetch(_ episodes: [Int: [EpisodeMetric]], failed: [Int] = []) -> SeasonFetchResult {
        SeasonFetchResult(episodesBySeason: episodes, failedSeasons: failed)
    }

    /// A slot analysed live from `episodes`, as its column.
    private func column(
        _ slot: Int,
        _ label: String,
        episodes: [EpisodeMetric],
        hasEnded: Bool? = nil
    ) throws -> CompareAnalysisColumn {
        let state = CompareSlotAnalysis.seeded(bundled: nil, hasEnded: hasEnded)
            .folding(fetch(grouped(episodes)), into: [:], hasEnded: hasEnded, asOf: EpisodeFixtures.now)
            .analysis
        let entry = CompareAnalysisEntry.make(
            slotIndex: slot, label: label, isSeries: true, isRetrying: false, analysis: state
        )
        guard case .analyzed(let column) = entry.state else {
            throw CompareFixtureError.notAnalyzed(String(describing: entry.state))
        }
        return column
    }

    private enum CompareFixtureError: Error {
        case notAnalyzed(String)
    }

    private func seasons(_ ratings: [[Double]]) -> [EpisodeMetric] {
        ratings.enumerated().flatMap { index, season in EpisodeFixtures.season(index + 1, ratings: season) }
    }

    private var bundled: SeriesAnalysis? {
        DatasetStore.shared.entry(forTMDBId: bundledSeriesId)?.analysis
    }

    // MARK: - Seeding and replacement

    @Test("a bundled series is seeded with the bundled analysis")
    func seedsFromBundle() throws {
        let bundled = try #require(bundled, "Breaking Bad should be in the bundled dataset")
        let state = CompareSlotAnalysis.seeded(bundled: bundled, hasEnded: true)

        #expect(state.result == .analyzed(bundled))
        #expect(state.source == .bundled)
    }

    @Test("a partial fetch keeps the bundled seed and offers a retry")
    func partialFetchKeepsSeed() throws {
        let bundled = try #require(bundled)
        let loaded = Array(bundled.seasons.map(\.seasonNumber).dropLast())
        let missing = bundled.seasons.last?.seasonNumber ?? 5

        let folded = CompareSlotAnalysis.seeded(bundled: bundled, hasEnded: true)
            .folding(fetch(bySeason(loaded), failed: [missing]), into: [:], hasEnded: true, asOf: EpisodeFixtures.now)

        #expect(folded.analysis.result == .analyzed(bundled))
        #expect(folded.analysis.source == .bundled)
        #expect(folded.analysis.failedSeasons == [missing])
        // The chart still gets what did load.
        #expect(folded.episodes.keys.sorted() == loaded)

        let entry = CompareAnalysisEntry.make(
            slotIndex: 0, label: "Breaking Bad", isSeries: true, isRetrying: false, analysis: folded.analysis
        )
        #expect(entry.isBundledFallback)
        #expect(entry.canRetry)
        #expect(entry.note?.detail.contains("bundled") == true)
    }

    @Test("a complete fetch covering every seeded season replaces the seed")
    func completeFetchReplacesSeed() throws {
        let bundled = try #require(bundled)
        let all = bundled.seasons.map(\.seasonNumber)

        let folded = CompareSlotAnalysis.seeded(bundled: bundled, hasEnded: true)
            .folding(fetch(bySeason(all)), into: [:], hasEnded: true, asOf: EpisodeFixtures.now)

        #expect(folded.analysis.source == .live)
        #expect(folded.analysis.finalAiredSeason == all.max())
        guard case .analyzed(let live) = folded.analysis.result else {
            Issue.record("expected a live analysis")
            return
        }
        #expect(live.seasons.map(\.seasonNumber) == all)
    }

    @Test("a partial fetch with no seed is refused, naming the gap, never shown as a fragment")
    func partialFetchWithoutSeedIsRefused() {
        let folded = CompareSlotAnalysis.seeded(bundled: nil, hasEnded: nil)
            .folding(fetch(bySeason([1, 2]), failed: [3]), into: [:], hasEnded: nil, asOf: EpisodeFixtures.now)

        #expect(folded.analysis.result == .insufficientData(.seasonsNotLoaded))

        let entry = CompareAnalysisEntry.make(
            slotIndex: 1, label: "Test Series", isSeries: true, isRetrying: false, analysis: folded.analysis
        )
        #expect(entry.state == .refused(.seasonsNotLoaded, failedSeasons: [3]))
        #expect(entry.canRetry)
        #expect(entry.note?.title == "Test Series: Some Seasons Didn't Load")
        #expect(entry.note?.detail.contains("season 3") == true)
    }

    @Test("a retry that loads the missing season turns the refusal into an analysis")
    func retryRecovers() {
        let first = CompareSlotAnalysis.seeded(bundled: nil, hasEnded: nil)
            .folding(fetch(bySeason([1, 2]), failed: [3]), into: [:], hasEnded: nil, asOf: EpisodeFixtures.now)
        let retried = first.analysis
            .folding(fetch(bySeason([3])), into: first.episodes, hasEnded: false, asOf: EpisodeFixtures.now)

        guard case .analyzed(let analysis) = retried.analysis.result else {
            Issue.record("expected an analysis after the retry")
            return
        }
        #expect(analysis.seasons.map(\.seasonNumber) == [1, 2, 3])
        #expect(retried.analysis.failedSeasons.isEmpty)
        #expect(retried.analysis.hasEnded == false)
    }

    @Test("a retry that fails outright keeps the seasons and the analysis already loaded")
    func failedRetryKeepsWhatLoaded() {
        let first = CompareSlotAnalysis.seeded(bundled: nil, hasEnded: nil)
            .folding(fetch(bySeason([1, 2, 3])), into: [:], hasEnded: nil, asOf: EpisodeFixtures.now)
        let retried = first.analysis
            .folding(fetch([:], failed: [1, 2, 3]), into: first.episodes, hasEnded: nil, asOf: EpisodeFixtures.now)

        #expect(retried.episodes.keys.sorted() == [1, 2, 3])
        #expect(retried.analysis.failedSeasons.isEmpty)
        #expect(retried.analysis.result == first.analysis.result)
    }

    @Test("Compare and the detail screen reach the same result from the same fetches")
    func sameRuleAsDetailScreen() {
        let media = MediaItem(
            id: -1, overview: "A real, non-stub series.", posterPath: nil, backdropPath: nil,
            voteAverage: 8, voteCount: 100, genreIds: nil, title: nil, releaseDate: nil,
            name: "Test Series", firstAirDate: nil, mediaType: .tv
        )
        let fetches = [
            fetch(bySeason([1, 2]), failed: [3]),
            fetch(bySeason([3])),
            fetch([:], failed: [1])
        ]

        let detail = MediaDetailViewModel(media: media)
        var slot = CompareSlotAnalysis.seeded(bundled: nil, hasEnded: nil)
        var held: [Int: [EpisodeMetric]] = [:]

        for fetched in fetches {
            detail.applySeasonFetch(fetched, asOf: EpisodeFixtures.now)
            let folded = slot.folding(fetched, into: held, hasEnded: nil, asOf: EpisodeFixtures.now)
            slot = folded.analysis
            held = folded.episodes

            #expect(slot.result == detail.analysis)
            #expect(slot.failedSeasons == detail.failedSeasons)
            #expect(held == detail.episodesBySeason)
        }
    }

    // MARK: - Refusals and slots with nothing to compare

    @Test("a refusal other than a missing season states its reason and offers no retry")
    func refusalWithoutRetry() {
        let thin = CompareSlotAnalysis.seeded(bundled: nil, hasEnded: nil)
            .folding(fetch(bySeason([1], ratings: [8.0, 8.1])), into: [:], hasEnded: nil, asOf: EpisodeFixtures.now)
        #expect(thin.analysis.result == .insufficientData(.notEnoughEpisodesToAnalyse))

        let entry = CompareAnalysisEntry.make(
            slotIndex: 0, label: "Pilot Only", isSeries: true, isRetrying: false, analysis: thin.analysis
        )
        #expect(!entry.canRetry)
        #expect(entry.note?.title == "Pilot Only: Not Enough Ratings Yet")
    }

    @Test("a series with nothing loaded says so and offers a retry")
    func nothingLoaded() {
        let entry = CompareAnalysisEntry.make(
            slotIndex: 2, label: "Offline", isSeries: true, isRetrying: false,
            analysis: .seeded(bundled: nil, hasEnded: nil)
        )
        #expect(entry.state == .unavailable)
        #expect(entry.canRetry)
    }

    @Test("a movie slot says the analysis applies to series")
    func movieSlot() {
        let entry = CompareAnalysisEntry.make(
            slotIndex: 0, label: "Heat", isSeries: false, isRetrying: false, analysis: nil
        )
        #expect(entry.state == .movie)
        #expect(entry.note?.detail == "Episode analysis applies to series.")
    }

    @Test("an analysis with no refusals yields no rows when nothing is analysed")
    func noColumnsNoRows() {
        #expect(CompareAnalysisTable.rows(for: []).isEmpty)
    }

    // MARK: - Highlighting

    @Test("only a strictly higher value is emphasised")
    func leaders() {
        #expect(CompareAnalysisTable.leaders([(0, 80), (1, 72)]) == [0])
        #expect(CompareAnalysisTable.leaders([(0, 70), (1, 90), (2, 85)]) == [1])
        // A tie has no higher value.
        #expect(CompareAnalysisTable.leaders([(0, 80), (1, 80)]).isEmpty)
        #expect(CompareAnalysisTable.leaders([(0, 80), (1, 80), (2, 60)]).isEmpty)
        // Nothing to be higher than.
        #expect(CompareAnalysisTable.leaders([(0, 80)]).isEmpty)
        #expect(CompareAnalysisTable.leaders([]).isEmpty)
    }

    @Test("only the score and its components are ever emphasised")
    func onlyNumericRowsHighlight() throws {
        let strong = try column(0, "Strong", episodes: seasons([[9.0, 9.1, 9.0, 9.2], [9.1, 9.0, 9.2, 9.1]]))
        let weak = try column(1, "Weak", episodes: seasons([[6.0, 7.5, 5.5, 7.0], [5.0, 6.5, 4.5, 6.0]]))
        let rows = CompareAnalysisTable.rows(for: [strong, weak])

        #expect(rows.map(\.kind) == CompareAnalysisTable.RowKind.allCases)
        for row in rows where !row.isNumeric {
            #expect(row.cells.allSatisfy { !$0.isHighlighted }, "\(row.title) must not emphasise a verdict")
        }
        let score = try #require(rows.first { $0.kind == .score })
        #expect(score.cells.first { $0.slotIndex == 0 }?.isHighlighted == true)
        #expect(score.cells.first { $0.slotIndex == 1 }?.isHighlighted == false)
    }

    // MARK: - Copy against its predicate

    @Test("each row reads as one sentence naming every title")
    func rowSentence() throws {
        let strong = try column(0, "Strong", episodes: seasons([[9.0, 9.1, 9.0, 9.2], [9.1, 9.0, 9.2, 9.1]]))
        let weak = try column(1, "Weak", episodes: seasons([[6.0, 7.5, 5.5, 7.0], [5.0, 6.5, 4.5, 6.0]]))
        let score = try #require(CompareAnalysisTable.rows(for: [strong, weak]).first { $0.kind == .score })

        let label = score.accessibilityLabel
        #expect(label.hasPrefix("Plotline Score: Strong, \(strong.analysis.score.value) out of 100, the higher of the two; "))
        #expect(label.hasSuffix("Weak, \(weak.analysis.score.value) out of 100."))
    }

    @Test("a decline is reported with its season and the numbers either side")
    func declineFound() throws {
        let falling = try column(0, "Falling", episodes: seasons([
            [9.0, 9.0, 9.1, 9.0], [9.0, 9.1, 9.0, 9.0], [7.5, 7.4, 7.5, 7.6], [7.5, 7.5, 7.4, 7.5]
        ]))
        guard case .declines(let point) = CompareAnalysisTable.declineFinding(falling) else {
            Issue.record("expected a decline")
            return
        }
        #expect(point.afterSeason == 2)
        #expect(CompareAnalysisTable.decline(falling).value == "Falls off after season 2")
    }

    @Test("'No lasting decline found' only when the engine's test actually ran")
    func noDeclineOnlyWhenTested() throws {
        let flat = try column(0, "Flat", episodes: seasons(Array(repeating: [8.0, 8.1, 8.0, 8.1], count: 4)))
        #expect(CompareAnalysisTable.declineFinding(flat) == .noneFound(checkedAfter: [2], throughSeason: 4))
        #expect(CompareAnalysisTable.decline(flat).value == "No lasting decline found")

        // Three seasons is too short a run for the engine to test at all.
        let short = try column(1, "Short", episodes: seasons(Array(repeating: [8.0, 8.1, 8.0, 8.1], count: 3)))
        #expect(CompareAnalysisTable.declineFinding(short) == .tooFewSeasons(judgeable: 3))
        #expect(CompareAnalysisTable.decline(short).value != "No lasting decline found")

        // A final season too thin to judge means "still down at the end" was
        // never tested either.
        var thinEnd = seasons(Array(repeating: [8.0, 8.1, 8.0, 8.1], count: 4))
        thinEnd.append(EpisodeFixtures.episode(season: 5, number: 1, rating: 8.0))
        let thin = try column(2, "Thin End", episodes: thinEnd)
        #expect(CompareAnalysisTable.declineFinding(thin) == .latestSeasonTooThin(5))
        #expect(CompareAnalysisTable.decline(thin).value != "No lasting decline found")
    }

    @Test("the ending verdict appears only for a series TMDB confirms has ended")
    func endingNeedsConfirmedEnd() throws {
        let run = seasons([[8.0, 8.1, 8.0, 8.1], [8.4, 8.5, 8.4, 8.5], [8.6, 8.5, 8.6, 8.5]])

        let ended = try column(0, "Ended Run", episodes: run, hasEnded: true)
        #expect(ended.analysis.endingVerdict != nil)
        #expect(CompareAnalysisTable.ending(ended).value == "Ends on a high")

        let unknown = try column(1, "Unknown", episodes: run, hasEnded: nil)
        let unknownCopy = CompareAnalysisTable.ending(unknown)
        #expect(unknownCopy.value == "No ending to judge")
        #expect(!unknownCopy.spoken.lowercased().contains("ended"))
        #expect(!unknownCopy.spoken.lowercased().contains("returning"))

        let returning = try column(2, "Returning", episodes: run, hasEnded: false)
        #expect(CompareAnalysisTable.ending(returning).detail == "TMDB lists it as returning or in production")
    }

    @Test("the evidence row counts the rated episodes the analysis rests on")
    func evidenceCount() throws {
        var episodes = seasons([[8.0, 8.1, 8.0, 8.1], [8.0, 8.1, 8.0, 8.1]])
        // Rated, but short of the vote floor: not part of the analysis.
        episodes.append(EpisodeFixtures.episode(season: 2, number: 5, rating: 9.9, votes: 2))
        let column = try column(0, "Counted", episodes: episodes)

        #expect(CompareAnalysisTable.evidence(column).value == "Based on 8 rated episodes")
    }

    @Test("no string in the section names a winner or calls an unknown status ended")
    func noForbiddenWording() throws {
        let columns = [
            try column(0, "A", episodes: seasons([[9.0, 9.1, 9.0, 9.2], [9.1, 9.0, 9.2, 9.1], [7.0, 7.1, 7.0, 7.2], [7.0, 7.0, 7.1, 7.0]]), hasEnded: nil),
            try column(1, "B", episodes: seasons(Array(repeating: [8.0, 8.1, 8.0, 8.1], count: 4)), hasEnded: false),
            try column(2, "C", episodes: seasons([[6.0, 7.5, 5.5, 7.0], [7.0, 8.5, 6.5, 8.0]]), hasEnded: nil)
        ]
        var strings = CompareAnalysisTable.rows(for: columns).flatMap { row in
            [row.title, row.caption ?? "", row.accessibilityLabel] + row.cells.flatMap { [$0.value, $0.detail ?? "", $0.spoken] }
        }
        let notes: [CompareAnalysisEntry] = [
            .make(slotIndex: 0, label: "M", isSeries: false, isRetrying: false, analysis: nil),
            .make(slotIndex: 1, label: "S", isSeries: true, isRetrying: false, analysis: .seeded(bundled: nil, hasEnded: nil))
        ]
        strings += notes.compactMap { $0.note }.flatMap { [$0.title, $0.detail] }

        let forbidden = ["ended", "winner", "wins", "better show", "best show", "never declines", "safe to skip"]
        for string in strings {
            for word in forbidden {
                #expect(!string.lowercased().contains(word), "\"\(string)\" contains \"\(word)\"")
            }
        }
    }
}
