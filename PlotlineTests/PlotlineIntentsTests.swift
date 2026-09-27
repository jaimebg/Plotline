import CoreSpotlight
import Foundation
import Testing
@testable import Plotline

// MARK: - Fixtures

/// Hand-built analyses, so every number the copy must carry is known.
enum IntentFixtures {
    static func season(_ number: Int, average: Double, reliable: Int) -> SeasonSummary {
        SeasonSummary(
            seasonNumber: number,
            weightedAverage: average,
            standardDeviation: 0.3,
            reliableEpisodeCount: reliable,
            airedEpisodeCount: reliable,
            bestEpisode: nil,
            worstEpisode: nil
        )
    }

    static func analysis(
        score: PlotlineScore = PlotlineScore(value: 86, level: 91, consistency: 77, trajectory: 64),
        decline: DeclinePoint? = nil,
        ending: EndingVerdict? = nil,
        isOngoing: Bool = false
    ) -> SeriesAnalysis {
        SeriesAnalysis(
            seasons: [
                season(1, average: 8.4, reliable: 10),
                season(2, average: 8.5, reliable: 10),
                season(3, average: 7.6, reliable: 10),
                season(4, average: 7.5, reliable: 9),
            ],
            bestSeason: 2,
            worstSeason: 4,
            declinePoint: decline,
            declineTest: nil,
            consistency: Consistency(rating: .steady, standardDeviation: 0.4, highestRated: nil, lowestRated: nil),
            standoutHighs: [],
            standoutLows: [],
            openingVerdict: nil,
            endingVerdict: ending,
            score: score,
            isOngoing: isOngoing
        )
    }

    static let decline = DeclinePoint(afterSeason: 2, averageBefore: 8.45, averageAfter: 7.55, seasonsAfter: [3, 4])

    static let fadingEnding = EndingVerdict(
        kind: .fadesOut,
        finalSeason: 4,
        finalSeasonAverage: 7.5,
        peakSeason: 2,
        peakSeasonAverage: 8.5
    )

    static func entry(id: Int, name: String, score: Int, firstAirDate: String? = "2008-01-20") -> DatasetEntry {
        DatasetEntry(
            tmdbId: id,
            name: name,
            mediaType: "tv",
            overview: "An overview.",
            posterPath: "/poster.jpg",
            backdropPath: nil,
            voteAverage: 8.0,
            genreIds: [18],
            firstAirDate: firstAirDate,
            analysis: analysis(score: PlotlineScore(value: score, level: score, consistency: score, trajectory: score)),
            awards: []
        )
    }

    static func dataset(_ entries: [DatasetEntry], generatedAt: String? = "2026-09-01T00:00:00Z") -> PlotlineDataset {
        PlotlineDataset(version: PlotlineDataset.currentVersion, entries: entries, lists: [], skipped: [], generatedAt: generatedAt)
    }

    /// Words a Siri answer must never use: "ended" for a status the engine
    /// only knows is not ongoing, and recommendation language the engine does
    /// not establish.
    static let forbiddenWords = ["ended", "worth", "must", "skip"]

    static func forbiddenWords(in text: String) -> [String] {
        let lowered = text.lowercased()
        return forbiddenWords.filter { lowered.contains($0) }
    }
}

// MARK: - Entity query ranking

@Suite("Series entity ranking")
struct SeriesEntityRankingTests {
    private func bundled(_ id: Int, _ name: String, score: Int) -> SeriesEntity {
        SeriesEntity(id: id, name: name, year: "2010", bundledScore: score)
    }

    private func searched(_ id: Int, _ name: String) -> SeriesEntity {
        SeriesEntity(id: id, name: name, year: nil, bundledScore: nil)
    }

    @Test("bundled matches lead, ahead of TMDB's own results")
    func bundledMatchesFirst() {
        let ranked = SeriesEntityRanking.rank(
            query: "office",
            bundled: [bundled(1, "The Office", score: 70), bundled(2, "Lost", score: 90)],
            searched: [searched(99, "Office Space Show"), searched(1, "The Office")]
        )

        #expect(ranked.map(\.id) == [1, 99])
        // The bundled copy is the one kept, score and all.
        #expect(ranked.first?.bundledScore == 70)
    }

    @Test("exact beats prefix beats substring, then the higher score")
    func matchQualityThenScore() {
        let ranked = SeriesEntityRanking.rank(
            query: "dark",
            bundled: [
                bundled(1, "The Dark Crystal", score: 95),
                bundled(2, "Dark Matter", score: 60),
                bundled(3, "Dark", score: 50),
                bundled(4, "Darkwing", score: 80),
            ],
            searched: []
        )

        #expect(ranked.map(\.id) == [3, 4, 2, 1])
    }

    @Test("a TMDB result that is a bundled series under another name is promoted")
    func promotesBundledSearchResults() {
        let ranked = SeriesEntityRanking.rank(
            query: "la casa",
            bundled: [bundled(71446, "Money Heist", score: 72)],
            searched: [searched(500, "La Casa de las Flores"), searched(71446, "La casa de papel")]
        )

        #expect(ranked.map(\.id) == [71446, 500])
        #expect(ranked.first?.name == "Money Heist")
    }

    @Test("matching ignores case and accents")
    func diacriticInsensitive() {
        let ranked = SeriesEntityRanking.rank(
            query: "POKEMON",
            bundled: [bundled(1, "Pokémon", score: 60)],
            searched: []
        )
        #expect(ranked.map(\.id) == [1])
    }

    @Test("no series appears twice")
    func deduplicates() {
        let ranked = SeriesEntityRanking.rank(
            query: "x",
            bundled: [],
            searched: [searched(1, "X"), searched(1, "X"), searched(2, "X2")]
        )
        #expect(ranked.map(\.id) == [1, 2])
    }

    @Test("suggestions are the bundled series, best score first")
    func suggestionsByScore() {
        let suggested = SeriesEntityRanking.suggested([
            bundled(1, "B", score: 70),
            bundled(2, "A", score: 90),
            bundled(3, "A2", score: 70),
        ])
        #expect(suggested.map(\.id) == [2, 3, 1])
    }
}

// MARK: - Verdict copy

@MainActor
@Suite("Siri verdict copy")
struct VerdictCopyTests {
    private let series = SeriesEntity(id: 1, name: "Example Show", year: "2008", bundledScore: 86)

    @Test("the dialog carries the score, all three components, the decline numbers and the basis")
    func dialogCarriesTheNumbers() {
        let analysis = IntentFixtures.analysis(decline: IntentFixtures.decline, ending: IntentFixtures.fadingEnding)
        let dialog = VerdictCopy.dialog(
            for: VerdictReport(series: series, outcome: .analyzed(analysis, source: .bundled))
        )

        #expect(dialog.contains("Plotline Score 86 out of 100"))
        #expect(dialog.contains("level 91"))
        #expect(dialog.contains("consistency 77"))
        #expect(dialog.contains("trajectory 64"))
        #expect(dialog.contains("Falls off after season 2"))
        #expect(dialog.contains("8.4") || dialog.contains("8.5"))
        #expect(dialog.contains("7.5") || dialog.contains("7.6"))
        #expect(dialog.contains("seasons 3, 4"))
        #expect(dialog.contains("Fades out at the end"))
        #expect(dialog.contains("Based on 39 episodes with enough votes to count"))
        #expect(dialog.contains("bundled analysis"))
        #expect(IntentFixtures.forbiddenWords(in: dialog).isEmpty)
    }

    @Test("a series not known to be ongoing, with no ending verdict, is never called ended")
    func unknownStatusIsNotEnded() {
        let analysis = IntentFixtures.analysis(isOngoing: false)
        for source in [VerdictSource.bundled, .live] {
            let dialog = VerdictCopy.dialog(for: VerdictReport(series: series, outcome: .analyzed(analysis, source: source)))
            #expect(IntentFixtures.forbiddenWords(in: dialog).isEmpty, "\(dialog)")
            #expect(!dialog.contains("Falls off"))
            #expect(!dialog.contains("at the end"))
        }
    }

    @Test("a live analysis says it was computed just now")
    func liveSource() {
        let dialog = VerdictCopy.dialog(
            for: VerdictReport(series: series, outcome: .analyzed(IntentFixtures.analysis(), source: .live))
        )
        #expect(dialog.contains("computed just now"))
        #expect(!dialog.contains("bundled"))
    }

    @Test(
        "every refusal states the engine's reason and no verdict",
        arguments: [
            InsufficientDataReason.noAiredEpisodes,
            .noReliableEpisodes,
            .tooFewReliableEpisodes,
            .notEnoughEpisodesToAnalyse,
            .seasonsNotLoaded,
        ]
    )
    func refusals(reason: InsufficientDataReason) {
        let dialog = VerdictCopy.dialog(
            for: VerdictReport(series: series, outcome: .refused(reason, failedSeasons: [3]))
        )

        #expect(dialog.hasPrefix("Plotline has no verdict on Example Show."))
        #expect(dialog.contains(SeriesAnalysisSection.explanation(for: reason, failedSeasons: [3])))
        #expect(!dialog.contains("Plotline Score"))
        #expect(IntentFixtures.forbiddenWords(in: dialog).isEmpty)
        if reason == .seasonsNotLoaded {
            #expect(dialog.contains("season 3"))
        }
    }

    @Test("a load that failed or ran out of time says so and points to the app")
    func unavailable() {
        for outcome in [VerdictReport.Outcome.couldNotLoad, .timedOut] {
            let dialog = VerdictCopy.dialog(for: VerdictReport(series: series, outcome: outcome))
            #expect(dialog.contains("couldn't load"))
            #expect(dialog.contains("Open Plotline"))
            #expect(!dialog.contains("Plotline Score"))
        }
    }

    @Test("the rated-episode count is the sum of the seasons' reliable episodes")
    func ratedEpisodeCount() {
        #expect(VerdictCopy.ratedEpisodeCount(IntentFixtures.analysis()) == 39)
        #expect(VerdictCopy.episodes(1) == "1 episode")
    }
}

// MARK: - Live verdict completeness

@Suite("Siri verdict completeness")
struct VerdictLoaderTests {
    private func fetch(seasons: [Int], failed: [Int] = []) -> SeasonFetchResult {
        var result = SeasonFetchResult()
        for season in seasons {
            result.episodesBySeason[season] = EpisodeFixtures.season(season, ratings: [8.0, 8.2, 7.9, 8.1, 8.3, 8.0])
        }
        result.failedSeasons = failed
        return result
    }

    @Test("a complete fetch is analysed, and marked live")
    func completeFetchIsAnalysed() {
        let outcome = VerdictLoader.outcome(for: fetch(seasons: [1, 2, 3]), hasEnded: nil, asOf: EpisodeFixtures.now)
        guard case .analyzed(_, let source) = outcome else {
            Issue.record("expected an analysis, got \(outcome)")
            return
        }
        #expect(source == .live)
    }

    @Test("any failed season means a refusal naming it, never a partial verdict")
    func partialFetchIsRefused() {
        let outcome = VerdictLoader.outcome(
            for: fetch(seasons: [1, 2, 4], failed: [3]),
            hasEnded: true,
            asOf: EpisodeFixtures.now
        )
        #expect(outcome == .refused(.seasonsNotLoaded, failedSeasons: [3]))
    }

    @Test("the engine's own refusal is passed through with its reason")
    func engineRefusalPassesThrough() {
        var thin = SeasonFetchResult()
        thin.episodesBySeason[1] = EpisodeFixtures.season(1, ratings: [8.0, 8.0], votes: 1)
        let outcome = VerdictLoader.outcome(for: thin, hasEnded: nil, asOf: EpisodeFixtures.now)
        #expect(outcome == .refused(.noReliableEpisodes, failedSeasons: []))
    }

    @Test("the time limit gives up on a slow operation")
    func timeLimitGivesUp() async {
        let value = await VerdictLoader.withTimeLimit(.milliseconds(50)) { () async -> Int in
            try? await Task.sleep(for: .seconds(10))
            return 1
        }
        #expect(value == nil)
    }

    @Test("the time limit returns a fast result")
    func timeLimitPassesThrough() async {
        let value = await VerdictLoader.withTimeLimit(.seconds(5)) { 42 }
        #expect(value == 42)
    }
}

// MARK: - What should I watch

@Suite("What should I watch pick")
struct WatchlistPickerTests {
    private func candidate(_ id: Int, _ title: String, series: Bool = true, rating: Double = 7.5) -> WatchlistCandidate {
        WatchlistCandidate(tmdbId: id, title: title, isSeries: series, voteAverage: rating)
    }

    private func analyses(_ scores: [Int: Int]) -> (Int) -> SeriesAnalysis? {
        { id in
            scores[id].map { IntentFixtures.analysis(score: PlotlineScore(value: $0, level: $0, consistency: $0, trajectory: $0)) }
        }
    }

    @Test("picks the analysed series with the highest Plotline Score")
    func highestScoreWins() {
        let pick = WatchlistPicker.pick(
            from: [candidate(1, "A"), candidate(2, "B"), candidate(3, "C")],
            analysis: analyses([1: 70, 2: 88]),
            randomIndex: { _ in Issue.record("no random pick expected"); return 0 }
        )
        guard case .highestScore(let chosen, let analysis, let compared) = pick else {
            Issue.record("expected a score pick, got \(pick)")
            return
        }
        #expect(chosen.tmdbId == 2)
        #expect(analysis.score.value == 88)
        #expect(compared == 2)
    }

    @Test("a movie never borrows the score of a series with the same TMDB id")
    func moviesAreNotLookedUp() {
        let pick = WatchlistPicker.pick(
            from: [candidate(1, "A Movie", series: false), candidate(2, "A Series")],
            analysis: analyses([1: 99, 2: 60])
        )
        guard case .highestScore(let chosen, _, _) = pick else {
            Issue.record("expected a score pick, got \(pick)")
            return
        }
        #expect(chosen.tmdbId == 2)
    }

    @Test("a tie goes to the title first alphabetically")
    func tieIsDeterministic() {
        let pick = WatchlistPicker.pick(
            from: [candidate(1, "Zeta"), candidate(2, "Alpha")],
            analysis: analyses([1: 80, 2: 80])
        )
        guard case .highestScore(let chosen, _, _) = pick else {
            Issue.record("expected a score pick, got \(pick)")
            return
        }
        #expect(chosen.title == "Alpha")
    }

    @Test("with no analysed series it falls back to a random pick, labelled as one")
    func randomFallback() {
        let pick = WatchlistPicker.pick(
            from: [candidate(1, "A", series: false), candidate(2, "B")],
            analysis: analyses([:]),
            randomIndex: { _ in 1 }
        )
        #expect(pick == .random(candidate(2, "B")))

        let dialog = WatchlistPicker.dialog(for: pick)
        #expect(dialog.contains("random pick"))
        #expect(!dialog.contains("Plotline Score"))
    }

    @Test("an empty watchlist says so")
    func emptyWatchlist() {
        #expect(WatchlistPicker.pick(from: [], analysis: analyses([:])) == .empty)
    }

    @Test("the score pick states its numbers, scoped to the analysed series")
    func scoreDialog() {
        let pick = WatchlistPicker.pick(
            from: [candidate(1, "A"), candidate(2, "B"), candidate(3, "Movie", series: false)],
            analysis: analyses([1: 70, 2: 86])
        )
        let dialog = WatchlistPicker.dialog(for: pick)

        #expect(dialog.contains("Highest Plotline Score among the 2 analysed series"))
        #expect(dialog.contains("B, at Plotline Score 86 out of 100"))
        #expect(dialog.contains("level 86, consistency 86, trajectory 86"))
        #expect(dialog.contains("39 episodes with enough votes to count"))
        #expect(IntentFixtures.forbiddenWords(in: dialog).isEmpty)
    }

    @Test("a single analysed series is not called the highest of one")
    func singleAnalysedSeries() {
        let pick = WatchlistPicker.pick(from: [candidate(1, "Solo")], analysis: analyses([1: 64]))
        let dialog = WatchlistPicker.dialog(for: pick)
        #expect(dialog.hasPrefix("The only series still to watch on your watchlist with a Plotline analysis is Solo"))
        #expect(!dialog.contains("Highest"))
    }
}

// MARK: - Spotlight

@Suite("Spotlight indexing")
struct SpotlightIndexerTests {
    private func freshDefaults() -> UserDefaults {
        let name = "SpotlightIndexerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private let dataset = IntentFixtures.dataset([
        IntentFixtures.entry(id: 1396, name: "Breaking Bad", score: 92),
        IntentFixtures.entry(id: 1399, name: "Game of Thrones", score: 71),
    ])

    @Test("a first launch indexes, and the same dataset is not indexed again")
    func indexesOncePerDataset() {
        let defaults = freshDefaults()
        let signature = SpotlightIndexer.signature(for: dataset)

        #expect(SpotlightIndexer.needsIndexing(signature: signature, defaults: defaults))
        SpotlightIndexer.markIndexed(signature: signature, defaults: defaults)
        #expect(!SpotlightIndexer.needsIndexing(signature: signature, defaults: defaults))
        // Recomputed from scratch, as the next launch would.
        #expect(!SpotlightIndexer.needsIndexing(signature: SpotlightIndexer.signature(for: dataset), defaults: defaults))
    }

    @Test("a regenerated dataset is indexed again")
    func newDatasetReindexes() {
        let defaults = freshDefaults()
        SpotlightIndexer.markIndexed(signature: SpotlightIndexer.signature(for: dataset), defaults: defaults)

        let regenerated = IntentFixtures.dataset(dataset.entries, generatedAt: "2026-10-01T00:00:00Z")
        #expect(SpotlightIndexer.needsIndexing(signature: SpotlightIndexer.signature(for: regenerated), defaults: defaults))
    }

    @Test("a changed score re-indexes even under the same generation date")
    func changedContentReindexes() {
        let defaults = freshDefaults()
        SpotlightIndexer.markIndexed(signature: SpotlightIndexer.signature(for: dataset), defaults: defaults)

        let rescored = IntentFixtures.dataset([
            IntentFixtures.entry(id: 1396, name: "Breaking Bad", score: 93),
            IntentFixtures.entry(id: 1399, name: "Game of Thrones", score: 71),
        ])
        #expect(SpotlightIndexer.needsIndexing(signature: SpotlightIndexer.signature(for: rescored), defaults: defaults))
    }

    @Test("an indexed series shows its year and bundled Plotline Score")
    func spotlightSummary() {
        let entity = SpotlightIndexer.entities(for: dataset).first
        #expect(entity?.id == 1396)
        #expect(entity?.spotlightSummary?.hasPrefix("2008 · Plotline Score 92 out of 100") == true)
        #expect(entity?.spotlightSummary?.contains("bundled analysis of 39 episodes") == true)
        #expect(entity?.attributeSet.contentDescription == entity?.spotlightSummary)
        #expect(SeriesEntity.subtitle(year: "2008", bundledScore: 92) == "2008 · Plotline Score 92")
    }
}

// MARK: - Opening a series

@MainActor
@Suite("Opening a series from Siri or Spotlight")
struct PendingDetailTests {
    @Test("a bundled series opens whole, so its analysis is in the first frame")
    func bundledSeriesOpensWhole() {
        let entry = IntentFixtures.entry(id: 1396, name: "Breaking Bad", score: 92)
        let item = PendingDetail(tmdbId: 1396, mediaType: .tv, name: "Breaking Bad").mediaItem(bundled: entry)
        #expect(item == entry.asMediaItem)
    }

    @Test("anything else opens as a stub the detail screen replaces")
    func otherSeriesOpensAsStub() {
        let item = PendingDetail(tmdbId: 42, mediaType: .tv, name: "Unbundled").mediaItem(bundled: nil)
        #expect(item.id == 42)
        #expect(item.isTVSeries)
        #expect(item.displayTitle == "Unbundled")
        // `MediaDetailViewModel.applyDetails` treats exactly this as a stub.
        #expect(item.voteAverage == 0 && item.overview.isEmpty)
    }

    @Test("opening a series also selects the Discover tab")
    func openDetailSelectsDiscover() {
        let manager = DeepLinkManager()
        manager.openDetail(PendingDetail(tmdbId: 7, mediaType: .tv))
        #expect(manager.pendingDetail?.tmdbId == 7)
        #expect(manager.pendingTab == .discover)
    }
}
