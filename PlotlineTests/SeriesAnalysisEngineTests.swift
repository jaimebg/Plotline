import Foundation
import Testing
@testable import Plotline

@Suite("SeriesAnalysisEngine — reliability and season summaries")
struct SeriesAnalysisEngineReliabilityTests {
    private func analyze(_ episodes: [EpisodeMetric]) -> SeriesAnalysisResult {
        SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now)
    }

    @Test("an empty series has no aired episodes")
    func emptySeries() {
        #expect(analyze([]) == .insufficientData(.noAiredEpisodes))
    }

    @Test("a series whose episodes have all not aired yet")
    func unairedSeries() {
        let episodes = (1...5).map {
            EpisodeFixtures.episode(season: 1, number: $0, rating: 0, votes: 0, airDate: EpisodeFixtures.futureAirDate)
        }
        #expect(analyze(episodes) == .insufficientData(.noAiredEpisodes))
    }

    @Test("a series where every episode has zero votes")
    func zeroVotesEverywhere() {
        let episodes = (1...8).map {
            EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 0)
        }
        #expect(analyze(episodes) == .insufficientData(.noReliableEpisodes))
    }

    @Test("a series where fewer than 60% of aired episodes are reliable")
    func belowReliabilityShare() {
        // 10 aired, only 5 with enough votes → 50%, under the 60% floor.
        var episodes = (1...5).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 50) }
        episodes += (6...10).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 3) }
        #expect(analyze(episodes) == .insufficientData(.tooFewReliableEpisodes))
    }

    @Test("episodes below the vote floor are excluded but do not block the analysis")
    func excludesLowVoteEpisodes() {
        // 10 aired, 8 reliable → 80%, above the floor.
        var episodes = (1...8).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 50) }
        episodes += (9...10).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 1.0, votes: 2) }

        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        // The two 1.0-rated episodes are excluded, so the average stays at 8.0.
        #expect(analysis.seasons.count == 1)
        #expect(abs(analysis.seasons[0].weightedAverage - 8.0) < 0.0001)
        #expect(analysis.seasons[0].reliableEpisodeCount == 8)
    }

    @Test("averages are weighted by vote count")
    func weightsByVoteCount() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 9.0, votes: 900),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 6.0, votes: 100),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 9.0, votes: 900),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 9.0, votes: 900)
        ]
        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        // Unweighted this would be 8.25; weighted it stays near 9.
        #expect(analysis.seasons[0].weightedAverage > 8.6)
    }

    @Test("season 0 specials are excluded")
    func excludesSeasonZero() {
        var episodes = EpisodeFixtures.season(0, ratings: [3.0, 3.0, 3.0])
        episodes += EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0, 8.0])

        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.seasons.map(\.seasonNumber) == [1])
    }

    @Test("unaired episodes are excluded and mark the series ongoing")
    func marksOngoing() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.2, 8.4, 8.1, 8.3])
        episodes.append(EpisodeFixtures.episode(season: 1, number: 6, rating: 0, votes: 0, airDate: EpisodeFixtures.futureAirDate))

        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.isOngoing)
        #expect(analysis.seasons[0].reliableEpisodeCount == 5)
    }

    @Test("season summaries name their best and worst episode")
    func summarisesSeasons() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0, title: "One"),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 9.5, title: "Two"),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 7.0, title: "Three"),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.5, title: "Four")
        ]
        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.seasons[0].bestEpisode?.title == "Two")
        #expect(analysis.seasons[0].worstEpisode?.title == "Three")
    }

    @Test("best and worst seasons are identified across a multi-season run")
    func identifiesBestAndWorstSeason() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.0, 9.0, 9.0, 9.0])
        episodes += EpisodeFixtures.season(3, ratings: [7.0, 7.0, 7.0, 7.0])

        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.bestSeason == 2)
        #expect(analysis.worstSeason == 3)
    }

    @Test("episode numbering gaps do not break the analysis")
    func toleratesNumberingGaps() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.2),
            EpisodeFixtures.episode(season: 1, number: 7, rating: 8.4),
            EpisodeFixtures.episode(season: 1, number: 12, rating: 8.1)
        ]
        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.seasons[0].reliableEpisodeCount == 4)
    }
}
