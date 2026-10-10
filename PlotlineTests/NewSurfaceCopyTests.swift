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

    @Test("the summary carries the name, score, season averages and basis")
    func fields() {
        let entry = ExplorerFixtures.entry(id: 7, name: "Example")
        let summary = FeaturedSeriesSummary(entry: entry)
        #expect(summary.title == "Example")
        #expect(summary.score == entry.analysis.score.value)
        #expect(summary.seasonAverages == entry.analysis.seasons.map(\.weightedAverage))
        #expect(summary.basis == VerdictCardContent.basis(for: entry.analysis))
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
