import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("Featured series summary")
struct FeaturedSeriesSummaryTests {
    @Test("a decline outranks every other verdict")
    func declineFirst() {
        let entry = ExplorerFixtures.entry(id: 1, ending: .endsSteady, consistency: .rollercoaster, declines: true)
        #expect(FeaturedSeriesSummary.verdict(for: entry.analysis) == "Falls off after season 2")
    }

    @Test("an ending the gate lets through comes next")
    func endingSecond() {
        let entry = ExplorerFixtures.entry(id: 1, ending: .endsStrong, isOngoing: false)
        #expect(FeaturedSeriesSummary.verdict(for: entry.analysis) == "Ends on a high")
    }

    @Test("a series listed as returning never shows its stored ending verdict")
    func ongoingSeriesNeverShowsEnding() {
        let entry = ExplorerFixtures.entry(id: 1, ending: .endsStrong, consistency: .steady, isOngoing: true)
        #expect(FeaturedSeriesSummary.verdict(for: entry.analysis) == "Holds a steady level")
    }

    @Test("otherwise the consistency verdict")
    func consistencyLast() {
        let entry = ExplorerFixtures.entry(id: 1, consistency: .verySteady)
        #expect(FeaturedSeriesSummary.verdict(for: entry.analysis) == "Remarkably even")
    }

    @Test("the curve caption is the share card's, word for word")
    func caption() {
        #expect(VerdictCardContent.seasonAveragesCaption == "Season averages, weighted by votes")
    }

    /// An entry whose analysed seasons carry these numbers and averages.
    private func makeEntry(seasons: [(number: Int, average: Double)]) -> DatasetEntry {
        let base = ExplorerFixtures.entry(id: 7, name: "Example")
        let a = base.analysis
        let summaries = seasons.map {
            SeasonSummary(seasonNumber: $0.number, weightedAverage: $0.average, standardDeviation: 0.2,
                          reliableEpisodeCount: 10, airedEpisodeCount: 10, bestEpisode: nil, worstEpisode: nil)
        }
        return DatasetEntry(
            tmdbId: base.tmdbId, name: base.name, mediaType: "tv", overview: "", posterPath: nil,
            backdropPath: "/b.jpg", voteAverage: 8, genreIds: [18], firstAirDate: base.firstAirDate,
            analysis: SeriesAnalysis(
                seasons: summaries, bestSeason: a.bestSeason, worstSeason: a.worstSeason,
                declinePoint: a.declinePoint, declineTest: a.declineTest, consistency: a.consistency,
                standoutHighs: [], standoutLows: [], openingVerdict: a.openingVerdict,
                endingVerdict: a.endingVerdict, score: a.score, isOngoing: a.isOngoing
            ),
            awards: []
        )
    }

    @Test("the summary carries the name, score, each season's number and average, and basis")
    func fields() {
        let entry = makeEntry(seasons: [(1, 8.1), (2, 8.4), (3, 7.6)])
        let summary = FeaturedSeriesSummary(entry: entry)
        #expect(summary.title == "Example")
        #expect(summary.score == entry.analysis.score.value)
        #expect(summary.seasonPoints.map(\.season) == entry.analysis.seasons.map(\.seasonNumber))
        #expect(summary.seasonPoints.map(\.average) == entry.analysis.seasons.map(\.weightedAverage))
        #expect(summary.basis == VerdictCardContent.basis(for: entry.analysis))
    }

    @Test("a season the analysis skips keeps its own number on the axis and for VoiceOver")
    func seasonGap() {
        // Blue Bloods' analysed seasons run 1–11 and then 14; numbering by
        // position would call season 14 "S12".
        let summary = FeaturedSeriesSummary(entry: makeEntry(seasons: [(1, 8.0), (2, 8.4), (4, 7.9)]))
        #expect(summary.seasonPoints.map(\.season) == [1, 2, 4])
        #expect(summary.seasonPoints.map(\.axisLabel) == ["S1", "S2", "S4"])
        #expect(FeaturedSeriesCard.accessibilityValue(for: summary).hasPrefix(
            "Season averages, weighted by votes: season 1, 8.0; season 2, 8.4; season 4, 7.9"
        ))
    }
}

@MainActor
@Suite("Curated shelf evidence")
struct CuratedShelfEvidenceTests {
    @Test("falls-off shows the decline title")
    func fallsOff() {
        let entry = ExplorerFixtures.entry(id: 1, declines: true)
        #expect(CuratedShelfEvidence.line(forShelf: "falls-off", analysis: entry.analysis) == "Falls off after season 2")
    }

    @Test("perfect-ending shows the ending title")
    func perfectEnding() {
        let entry = ExplorerFixtures.entry(id: 1, ending: .endsStrong)
        #expect(CuratedShelfEvidence.line(forShelf: "perfect-ending", analysis: entry.analysis) == "Ends on a high")
    }

    @Test("perfect-ending says nothing for a series listed as returning")
    func perfectEndingRespectsTheGate() {
        let entry = ExplorerFixtures.entry(id: 1, ending: .endsStrong, isOngoing: true)
        #expect(CuratedShelfEvidence.line(forShelf: "perfect-ending", analysis: entry.analysis) == nil)
    }

    @Test("slow-burn shows the opening title with the season it improves from")
    func slowBurn() {
        let base = ExplorerFixtures.entry(id: 1)
        let opening = OpeningVerdict(kind: .slowStart, openingAverage: 7, remainderAverage: 8,
                                     episodesConsidered: [], improvesAtSeason: 3)
        let a = base.analysis
        let analysis = SeriesAnalysis(
            seasons: a.seasons, bestSeason: a.bestSeason, worstSeason: a.worstSeason,
            declinePoint: nil, declineTest: a.declineTest, consistency: a.consistency,
            standoutHighs: [], standoutLows: [], openingVerdict: opening,
            endingVerdict: nil, score: a.score, isOngoing: a.isOngoing
        )
        #expect(CuratedShelfEvidence.line(forShelf: "slow-burn", analysis: analysis) == "Slow start, better from season 3")
    }

    @Test("rollercoaster shows the consistency title")
    func rollercoaster() {
        let entry = ExplorerFixtures.entry(id: 1, consistency: .rollercoaster)
        #expect(CuratedShelfEvidence.line(forShelf: "rollercoaster", analysis: entry.analysis) == "A rollercoaster")
    }

    @Test("never-decline shows the Analysis tab's no-decline label, and nothing if a decline exists")
    func neverDecline() {
        let steady = ExplorerFixtures.entry(id: 1)
        #expect(CuratedShelfEvidence.line(forShelf: "never-decline", analysis: steady.analysis) == "No decline point found")
        #expect(AnalysisTrait.noDeclineFound.label == "No decline point found")

        let falling = ExplorerFixtures.entry(id: 2, declines: true)
        #expect(CuratedShelfEvidence.line(forShelf: "never-decline", analysis: falling.analysis) == nil)
    }

    @Test("an unknown shelf has no evidence line")
    func unknownShelf() {
        #expect(CuratedShelfEvidence.line(forShelf: "not-a-list", analysis: ExplorerFixtures.entry(id: 1).analysis) == nil)
    }
}
