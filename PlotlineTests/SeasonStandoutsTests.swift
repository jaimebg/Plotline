import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("Season highs and lows")
struct SeasonStandoutsTests {
    private func reference(season: Int, episode: Int, rating: Double) -> EpisodeReference {
        EpisodeReference(id: season * 1_000 + episode, seasonNumber: season, episodeNumber: episode, title: "E", rating: rating)
    }

    private func summary(season: Int, average: Double, reliable: Int) -> SeasonSummary {
        SeasonSummary(
            seasonNumber: season,
            weightedAverage: average,
            standardDeviation: 0.4,
            reliableEpisodeCount: reliable,
            airedEpisodeCount: reliable,
            bestEpisode: nil,
            worstEpisode: nil
        )
    }

    private func analysis(highs: [EpisodeReference], lows: [EpisodeReference]) -> SeriesAnalysis {
        SeriesAnalysis(
            seasons: [summary(season: 3, average: 8.3, reliable: 9)],
            bestSeason: nil,
            worstSeason: nil,
            declinePoint: nil,
            consistency: Consistency(rating: .steady, standardDeviation: 0.4, highestRated: nil, lowestRated: nil),
            standoutHighs: highs,
            standoutLows: lows,
            openingVerdict: nil,
            endingVerdict: nil,
            score: PlotlineScore(value: 80, level: 83, consistency: 60, trajectory: 50),
            isOngoing: false
        )
    }

    // MARK: - Copy

    @Test("a high states the distance above its own season's average and the sample")
    func highLineStatesTheRelation() {
        let line = SeasonStandoutsView.line(
            for: reference(season: 3, episode: 7, rating: 9.4),
            direction: .high,
            season: summary(season: 3, average: 8.3, reliable: 9)
        )
        #expect(line == "S3E7 · 9.4 — 1.1 above season 3's weighted average of 8.3 (from 9 episodes with enough votes)")
    }

    @Test("a low states the distance below, as a positive number")
    func lowLineStatesTheRelation() {
        let line = SeasonStandoutsView.line(
            for: reference(season: 2, episode: 4, rating: 6.1),
            direction: .low,
            season: summary(season: 2, average: 7.8, reliable: 12)
        )
        #expect(line == "S2E4 · 6.1 — 1.7 below season 2's weighted average of 7.8 (from 12 episodes with enough votes)")
    }

    @Test("without the season summary only the episode and rating are stated")
    func missingSummaryStatesNoRelation() {
        let line = SeasonStandoutsView.line(
            for: reference(season: 2, episode: 4, rating: 6.1),
            direction: .low,
            season: nil
        )
        #expect(line == "S2E4 · 6.1")
    }

    /// The six rewritten strings all failed the same way. None of these words
    /// is supported by "far from its season's average".
    @Test("no standout copy claims more than the predicate")
    func copyMakesNoValueJudgement() {
        let copy = [
            SeasonStandoutsView.predicateExplanation,
            SeasonStandoutsView.line(
                for: reference(season: 1, episode: 1, rating: 9.0),
                direction: .high,
                season: summary(season: 1, average: 8.0, reliable: 6)
            ),
            SeasonStandoutsView.line(
                for: reference(season: 1, episode: 2, rating: 7.0),
                direction: .low,
                season: summary(season: 1, average: 8.0, reliable: 6)
            ),
            StandoutDirection.high.legend,
            StandoutDirection.low.legend
        ].joined(separator: " ").lowercased()

        for banned in ["essential", "must", "skip", "safe", "best", "worst", "don't miss"] {
            #expect(!copy.contains(banned), "found \(banned)")
        }
    }

    @Test("the predicate explanation quotes the engine's own thresholds")
    func explanationQuotesThresholds() {
        let text = SeasonStandoutsView.predicateExplanation
        #expect(text.contains(String(format: "%.1f standard deviations", SeriesAnalysisEngine.standoutZScoreThreshold)))
        #expect(text.contains(String(format: "%.1f points", SeriesAnalysisEngine.minimumStandoutDelta)))
        #expect(text.contains("\(SeriesAnalysisEngine.minimumEpisodesForZScore) or more"))
    }

    // MARK: - Index

    @Test("the index places highs and lows by season and episode")
    func indexPlacesStandouts() {
        let index = StandoutIndex(analysis: analysis(
            highs: [reference(season: 3, episode: 7, rating: 9.4)],
            lows: [reference(season: 3, episode: 2, rating: 7.0)]
        ))
        #expect(index.direction(season: 3, episode: 7) == .high)
        #expect(index.direction(season: 3, episode: 2) == .low)
        #expect(index.direction(season: 2, episode: 7) == nil)
        #expect(index.directions(inSeason: 3) == [7: .high, 2: .low])
        #expect(!index.isEmpty)
        #expect(StandoutIndex.empty.isEmpty)
    }

    // MARK: - Compatibility

    /// The Swift names changed from `essentialEpisodes`/`skippableEpisodes`;
    /// the bundled dataset still carries the old keys and must keep decoding.
    @Test("the renamed fields still read and write the dataset's keys")
    func renamedFieldsKeepTheirKeys() throws {
        let original = analysis(
            highs: [reference(season: 3, episode: 7, rating: 9.4)],
            lows: [reference(season: 3, episode: 2, rating: 7.0)]
        )
        let data = try JSONEncoder().encode(original)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["essentialEpisodes"] != nil)
        #expect(object["skippableEpisodes"] != nil)
        #expect(object["standoutHighs"] == nil)
        #expect(try JSONDecoder().decode(SeriesAnalysis.self, from: data) == original)
    }

    @Test("the bundled dataset's standouts decode into the renamed fields")
    func bundledDatasetDecodes() {
        let entries = DatasetStore.shared.entries
        #expect(!entries.isEmpty)
        let total = entries.reduce(0) { $0 + $1.analysis.standoutHighs.count + $1.analysis.standoutLows.count }
        #expect(total > 0)
    }
}
