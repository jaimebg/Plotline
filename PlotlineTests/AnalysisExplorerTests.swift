import Foundation
import Testing
@testable import Plotline

// MARK: - Fixtures

enum ExplorerFixtures {
    static func opening(_ kind: OpeningVerdict.Kind) -> OpeningVerdict {
        OpeningVerdict(kind: kind, openingAverage: 8, remainderAverage: 8, episodesConsidered: [], improvesAtSeason: nil)
    }

    static func ending(_ kind: EndingVerdict.Kind) -> EndingVerdict {
        EndingVerdict(kind: kind, finalSeason: 3, finalSeasonAverage: 8, peakSeason: 2, peakSeasonAverage: 8.5)
    }

    static let decline = DeclinePoint(afterSeason: 2, averageBefore: 8.5, averageAfter: 7.5, seasonsAfter: [3, 4])

    static func entry(
        id: Int,
        name: String? = nil,
        score: PlotlineScore = PlotlineScore(value: 80, level: 80, consistency: 80, trajectory: 50),
        opening: OpeningVerdict.Kind? = .even,
        ending: EndingVerdict.Kind? = nil,
        consistency: ConsistencyRating = .steady,
        declines: Bool = false,
        isOngoing: Bool = false,
        genreIds: [Int] = [18],
        firstAirDate: String? = "2010-05-01"
    ) -> DatasetEntry {
        DatasetEntry(
            tmdbId: id,
            name: name ?? "Series \(id)",
            mediaType: "tv",
            overview: "",
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 8,
            genreIds: genreIds,
            firstAirDate: firstAirDate,
            analysis: SeriesAnalysis(
                seasons: [],
                bestSeason: nil,
                worstSeason: nil,
                declinePoint: declines ? decline : nil,
                consistency: Consistency(rating: consistency, standardDeviation: 0.4, highestRated: nil, lowestRated: nil),
                standoutHighs: [],
                standoutLows: [],
                openingVerdict: opening.map(Self.opening),
                endingVerdict: ending.map(Self.ending),
                score: score,
                isOngoing: isOngoing
            ),
            awards: []
        )
    }
}

/// Stands in for Apple's on-device model.
@MainActor
struct FakeTranslator: AnalysisRequestTranslating {
    var availability: AnalysisTranslatorAvailability = .available
    var result: Result<AnalysisRequestInterpretation, AnalysisTranslationError>

    func interpret(_ request: String, genreNames: [String]) async throws -> AnalysisRequestInterpretation {
        try result.get()
    }
}

// MARK: - Predicates

@MainActor
@Suite("Analysis trait predicates")
struct AnalysisTraitPredicateTests {
    @Test("each opening chip matches exactly its verdict kind, and nothing without an opening verdict")
    func openingChips() {
        let hooks = ExplorerFixtures.entry(id: 1, opening: .hooksEarly)
        let none = ExplorerFixtures.entry(id: 2, opening: nil)
        #expect(AnalysisTrait.opening(.hooksEarly).matches(hooks))
        #expect(!AnalysisTrait.opening(.slowStart).matches(hooks))
        #expect(!AnalysisTrait.opening(.even).matches(hooks))
        for trait in AnalysisTrait.traits(in: .opening) {
            #expect(!trait.matches(none))
        }
    }

    @Test("ending chips never match a series with no ending verdict, whatever its status")
    func endingChipsNeedAnEnding() {
        // No ending verdict is what the engine produces for a running series
        // and for one whose status is unknown alike.
        let running = ExplorerFixtures.entry(id: 1, ending: nil, isOngoing: true)
        let unknownOrEnded = ExplorerFixtures.entry(id: 2, ending: nil, isOngoing: false)
        for trait in AnalysisTrait.traits(in: .ending) {
            #expect(!trait.matches(running))
            #expect(!trait.matches(unknownOrEnded))
        }
        let strong = ExplorerFixtures.entry(id: 3, ending: .endsStrong)
        #expect(AnalysisTrait.ending(.endsStrong).matches(strong))
        #expect(!AnalysisTrait.ending(.fadesOut).matches(strong))
    }

    @Test("status chips follow isOngoing, and the false side is never labelled ended")
    func statusChips() {
        let running = ExplorerFixtures.entry(id: 1, isOngoing: true)
        let notRunning = ExplorerFixtures.entry(id: 2, isOngoing: false)
        #expect(AnalysisTrait.stillRunning.matches(running))
        #expect(!AnalysisTrait.stillRunning.matches(notRunning))
        #expect(AnalysisTrait.notKnownToBeRunning.matches(notRunning))
        #expect(!AnalysisTrait.notKnownToBeRunning.matches(running))

        // `isOngoing == false` is ended *or* unknown.
        for trait in AnalysisTrait.traits(in: .status) {
            #expect(!trait.label.localizedCaseInsensitiveContains("ended"))
            #expect(!trait.label.localizedCaseInsensitiveContains("finished"))
        }
    }

    @Test("the decline chips split on the presence of a decline point, and the absent one claims only absence")
    func declineChips() {
        let falls = ExplorerFixtures.entry(id: 1, declines: true)
        let holds = ExplorerFixtures.entry(id: 2, declines: false)
        #expect(AnalysisTrait.declineFound.matches(falls))
        #expect(!AnalysisTrait.declineFound.matches(holds))
        #expect(AnalysisTrait.noDeclineFound.matches(holds))
        #expect(!AnalysisTrait.noDeclineFound.matches(falls))
        #expect(AnalysisTrait.noDeclineFound.label == "No decline point found")
    }

    @Test("consistency chips match only their own rating")
    func consistencyChips() {
        let entry = ExplorerFixtures.entry(id: 1, consistency: .rollercoaster)
        #expect(AnalysisTrait.traits(in: .consistency).filter { $0.matches(entry) } == [.consistency(.rollercoaster)])
    }

    @Test("chip labels are the detail screen's verdict titles for the same value")
    func labelsMatchTheDetailScreen() {
        for kind in [EndingVerdict.Kind.endsStrong, .endsSteady, .fadesOut] {
            #expect(AnalysisTrait.ending(kind).label == SeriesVerdictsView.endingTitle(ExplorerFixtures.ending(kind)))
        }
    }

    @Test("every trait lives in the category it says it does")
    func categoriesAreConsistent() {
        for category in TraitCategory.allCases {
            for trait in AnalysisTrait.traits(in: category) {
                #expect(trait.category == category)
            }
        }
    }
}

// MARK: - Combining, sorting, counting

@MainActor
@Suite("Analysis explorer filtering")
struct AnalysisExplorerFilteringTests {
    let entries = [
        ExplorerFixtures.entry(id: 1, opening: .hooksEarly, ending: .endsStrong, consistency: .verySteady),
        ExplorerFixtures.entry(id: 2, opening: .slowStart, ending: .fadesOut, consistency: .steady),
        ExplorerFixtures.entry(id: 3, opening: .even, ending: nil, consistency: .steady, isOngoing: true),
        ExplorerFixtures.entry(id: 4, opening: .hooksEarly, ending: .endsSteady, consistency: .uneven, genreIds: [35]),
    ]

    private func ids(_ selection: Set<AnalysisTrait>) -> Set<Int> {
        Set(AnalysisExplorer.results(entries, selection: selection, sort: .plotlineScore).map(\.tmdbId))
    }

    @Test("an empty selection matches everything")
    func emptySelection() {
        #expect(ids([]) == [1, 2, 3, 4])
    }

    @Test("chips in the same category combine with OR")
    func orWithinCategory() {
        #expect(ids([.ending(.endsStrong), .ending(.fadesOut)]) == [1, 2])
        #expect(ids([.consistency(.verySteady), .consistency(.steady)]) == [1, 2, 3])
    }

    @Test("chips in different categories combine with AND")
    func andAcrossCategories() {
        #expect(ids([.opening(.hooksEarly), .consistency(.verySteady)]) == [1])
        #expect(ids([.opening(.hooksEarly), .ending(.endsStrong), .ending(.endsSteady)]) == [1, 4])
        #expect(ids([.opening(.hooksEarly), .genre(35)]) == [4])
        #expect(ids([.opening(.slowStart), .stillRunning]).isEmpty)
    }

    @Test("dropping a category reports how many series it was holding back")
    func matchesWithout() {
        let selection: Set<AnalysisTrait> = [.opening(.slowStart), .stillRunning]
        let without = AnalysisExplorer.matchesWithout(entries, selection: selection)
        #expect(without.map(\.category) == [.opening, .status])
        // Without the opening filter, only the running series is left;
        // without the status filter, only the slow starter.
        #expect(without.map(\.count) == [1, 1])
    }

    @Test("results sort by the chosen score component, highest first, then by score and name")
    func sorting() {
        let a = ExplorerFixtures.entry(id: 1, name: "Alpha", score: PlotlineScore(value: 70, level: 90, consistency: 40, trajectory: 50))
        let b = ExplorerFixtures.entry(id: 2, name: "Beta", score: PlotlineScore(value: 85, level: 80, consistency: 95, trajectory: 40))
        let c = ExplorerFixtures.entry(id: 3, name: "Gamma", score: PlotlineScore(value: 60, level: 60, consistency: 50, trajectory: 90))
        let d = ExplorerFixtures.entry(id: 4, name: "Delta", score: PlotlineScore(value: 60, level: 70, consistency: 50, trajectory: 90))
        let all = [a, b, c, d]

        func order(_ sort: AnalysisSort) -> [String] {
            AnalysisExplorer.results(all, selection: [], sort: sort).map(\.name)
        }
        #expect(order(.plotlineScore) == ["Beta", "Alpha", "Delta", "Gamma"])
        #expect(order(.level) == ["Alpha", "Beta", "Delta", "Gamma"])
        #expect(order(.consistency) == ["Beta", "Delta", "Gamma", "Alpha"])
        #expect(order(.trajectory) == ["Delta", "Gamma", "Alpha", "Beta"])
    }

    @Test("the count is computed from the data it describes")
    func counting() {
        #expect(AnalysisExplorer.countSummary(matched: 12, total: 123) == "12 of 123 analysed series")

        let model = AnalysisExplorerViewModel(entries: entries, translator: FakeTranslator(result: .success(.init())))
        #expect(model.countSummary == "4 of 4 analysed series")
        model.toggle(.opening(.hooksEarly))
        #expect(model.countSummary == "2 of 4 analysed series")
        model.toggle(.opening(.hooksEarly))
        #expect(model.countSummary == "4 of 4 analysed series")
    }

    @Test("genre chips come from the data: only named genres, most common first")
    func genreChips() {
        let withUnknown = entries + [ExplorerFixtures.entry(id: 5, genreIds: [35, 999_999])]
        #expect(AnalysisExplorer.genreTraits(in: withUnknown) == [.genre(18), .genre(35)])
    }

    @Test("the bundled dataset filters to a subset and counts it against its own size")
    func bundledDataset() {
        let bundled = DatasetStore.shared.entries
        #expect(!bundled.isEmpty)
        let model = AnalysisExplorerViewModel(entries: bundled, translator: FakeTranslator(result: .success(.init())))
        #expect(model.results.count == bundled.count)
        model.toggle(.ending(.endsStrong))
        #expect(model.results.allSatisfy { $0.analysis.endingVerdict?.kind == .endsStrong })
        #expect(model.countSummary == "\(model.results.count) of \(bundled.count) analysed series")
    }
}

// MARK: - Natural language → chips

@MainActor
@Suite("Natural-language requests become chips")
struct AnalysisRequestMappingTests {
    let entries = [
        ExplorerFixtures.entry(id: 1, ending: .endsStrong, consistency: .verySteady, genreIds: [18]),
        ExplorerFixtures.entry(id: 2, ending: .fadesOut, consistency: .steady, genreIds: [35]),
    ]

    @Test("an interpretation selects exactly its chips and sort")
    func appliesInterpretation() async {
        let interpretation = AnalysisRequestInterpretation(
            openings: [.slowStart],
            endings: [.endsStrong],
            consistencies: [.verySteady, .steady],
            declineFound: false,
            stillRunning: false,
            genreNames: ["drama"],
            sort: .consistency
        )
        let model = AnalysisExplorerViewModel(entries: entries, translator: FakeTranslator(result: .success(interpretation)))
        model.request = "a slow-burn drama that ends strong and stays steady"
        await model.interpretRequest()

        #expect(model.selection == [
            .opening(.slowStart), .ending(.endsStrong),
            .consistency(.verySteady), .consistency(.steady),
            .noDeclineFound, .notKnownToBeRunning, .genre(18),
        ])
        #expect(model.sort == .consistency)
        guard case .interpreted(_, _, let unmatched) = model.requestState else {
            Issue.record("expected an interpretation, got \(model.requestState)")
            return
        }
        #expect(unmatched.isEmpty)
    }

    @Test("a genre the dataset does not carry is reported, not applied")
    func unmatchedGenre() {
        let interpretation = AnalysisRequestInterpretation(endings: [.endsStrong], genreNames: ["Western"])
        let (selection, unmatched) = interpretation.selection(
            availableGenres: AnalysisExplorer.genreTraits(in: entries)
        )
        #expect(selection == [.ending(.endsStrong)])
        #expect(unmatched == ["Western"])
    }

    @Test("an interpretation that maps to nothing leaves the viewer's chips alone")
    func emptyInterpretationKeepsChips() async {
        let model = AnalysisExplorerViewModel(entries: entries, translator: FakeTranslator(result: .success(.init())))
        model.toggle(.ending(.fadesOut))
        model.request = "something good"
        await model.interpretRequest()
        #expect(model.selection == [.ending(.fadesOut)])
        #expect(model.requestState == .interpreted(selection: [], sort: nil, unmatchedGenres: []))
    }

    @Test("a translation error keeps the chips and says why")
    func translationError() async {
        let model = AnalysisExplorerViewModel(entries: entries, translator: FakeTranslator(result: .failure(.declined)))
        model.toggle(.consistency(.steady))
        model.request = "anything"
        await model.interpretRequest()
        #expect(model.selection == [.consistency(.steady)])
        #expect(model.requestState == .failed(AnalysisTranslationError.declined.message))
    }

    @Test("a blank request never reaches the translator")
    func blankRequest() async {
        let model = AnalysisExplorerViewModel(entries: entries, translator: FakeTranslator(result: .failure(.failed)))
        model.request = "   "
        await model.interpretRequest()
        #expect(model.requestState == .idle)
    }

    @Test("an unavailable model is reported as such")
    func unavailable() {
        let model = AnalysisExplorerViewModel(
            entries: entries,
            translator: FakeTranslator(availability: .unavailable("Off"), result: .failure(.unavailable))
        )
        #expect(model.translatorAvailability == .unavailable("Off"))
    }

    @Test("the model's schema maps one-to-one onto the chips' terms")
    func generatedFilterMapping() {
        let generated = GeneratedAnalysisFilter(
            mentioned: [.opening, .consistency, .decline, .status, .genre, .order],
            opening: [.hooksEarly, .hooksEarly],
            ending: [],
            consistency: [.rollercoaster],
            decline: .declines,
            status: .notKnownToBeRunning,
            genres: ["Comedy", "Comedy"],
            order: .trajectory
        )
        #expect(generated.interpretation == AnalysisRequestInterpretation(
            openings: [.hooksEarly],
            endings: [],
            consistencies: [.rollercoaster],
            declineFound: true,
            stillRunning: false,
            genreNames: ["Comedy"],
            sort: .trajectory
        ))

        let noPreference = GeneratedAnalysisFilter(
            mentioned: [],
            opening: [], ending: [], consistency: [],
            decline: .noPreference, status: .noPreference,
            genres: [], order: .noPreference
        )
        #expect(noPreference.interpretation == AnalysisRequestInterpretation())
    }

    @Test("slots for aspects the description never mentioned are ignored")
    func unmentionedAspectsAreDropped() {
        // What the on-device model actually did with "a finished show that
        // ends strong and stays steady" before the aspect gate existed: it
        // filled every slot.
        let generated = GeneratedAnalysisFilter(
            mentioned: [.ending, .consistency],
            opening: [.even],
            ending: [.endsStrong],
            consistency: [.verySteady, .steady],
            decline: .noDecline,
            status: .notKnownToBeRunning,
            genres: ["Drama"],
            order: .plotlineScore
        )
        #expect(generated.interpretation == AnalysisRequestInterpretation(
            endings: [.endsStrong],
            consistencies: [.verySteady, .steady]
        ))
    }

    @Test("still running next to an ending request is dropped, since no series could match both")
    func runningContradictsEnding() {
        let generated = GeneratedAnalysisFilter(
            mentioned: [.ending, .status],
            opening: [], ending: [.endsStrong], consistency: [],
            decline: .noPreference, status: .stillRunning,
            genres: [], order: .noPreference
        )
        #expect(generated.interpretation.endings == [.endsStrong])
        #expect(generated.interpretation.stillRunning == nil)
    }

    @Test("the summary names the chips the request set, grouped by category")
    func summary() {
        let text = AnalysisExplorerViewModel.interpretationSummary(
            selection: [.ending(.endsStrong), .consistency(.steady), .consistency(.verySteady)],
            sort: .plotlineScore,
            unmatchedGenres: []
        )
        #expect(text == "Interpreted as: Ending — Ends on a high · Consistency — Holds a steady level or Remarkably even · sorted by Plotline Score")
    }
}

// MARK: - Library

@MainActor
@Suite("Library segments")
struct LibrarySegmentTests {
    @Test("opening the library on a segment selects the Library tab and leaves the segment pending")
    func deepLink() {
        let manager = DeepLinkManager()
        manager.openLibrary(.favorites)
        #expect(manager.pendingTab == .library)
        #expect(manager.pendingLibrarySegment == .favorites)

        manager.openLibrary(.watchlist)
        #expect(manager.pendingLibrarySegment == .watchlist)
    }

    @Test("the persisted raw values stay put, or every viewer's last choice is forgotten")
    func persistedValues() {
        #expect(LibrarySegment.allCases.map(\.rawValue) == ["watchlist", "favorites"])
        #expect(LibrarySegment(rawValue: "favorites") == .favorites)
    }

    @Test("the segment titles are the labels the UI suite taps")
    func titles() {
        #expect(LibrarySegment.allCases.map(\.title) == ["Watchlist", "Favorites"])
    }
}
