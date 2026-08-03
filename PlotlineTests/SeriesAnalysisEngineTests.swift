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

@Suite("SeriesAnalysisEngine — weighted standard deviation")
struct SeriesAnalysisEngineStandardDeviationTests {
    private func analyze(_ episodes: [EpisodeMetric]) -> SeriesAnalysisResult {
        SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now)
    }

    @Test("a flat season (every rating identical) has zero standard deviation")
    func flatSeasonHasZeroStandardDeviation() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0], votes: 100)
        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.seasons[0].standardDeviation == 0)
    }

    @Test("a season with a single reliable episode has zero standard deviation")
    func singleEpisodeHasZeroStandardDeviation() {
        let episodes = [EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0, votes: 100)]
        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(analysis.seasons[0].standardDeviation == 0)
    }

    @Test("equal vote weights produce the population standard deviation")
    func equalWeightsProducePopulationStandardDeviation() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 7.0, votes: 100),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.0, votes: 100),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 9.0, votes: 100)
        ]
        guard case .analyzed(let analysis) = analyze(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        // Mean is 8.0; population standard deviation of [7, 8, 9] is sqrt(2/3) ≈ 0.8165.
        #expect(abs(analysis.seasons[0].weightedAverage - 8.0) < 0.0001)
        #expect(abs(analysis.seasons[0].standardDeviation - 0.8165) < 0.001)
    }

    @Test("down-weighting an outlier's votes shrinks the standard deviation")
    func downweightingOutlierShrinksStandardDeviation() {
        // Same three ratings as the equal-weight case above, but the 9.0 outlier
        // now carries far fewer votes (still above the reliability floor).
        let evenlyWeighted = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 7.0, votes: 100),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.0, votes: 100),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 9.0, votes: 100)
        ]
        let outlierDownweighted = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 7.0, votes: 100),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.0, votes: 100),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 9.0, votes: 10)
        ]
        guard case .analyzed(let evenAnalysis) = analyze(evenlyWeighted),
              case .analyzed(let downweightedAnalysis) = analyze(outlierDownweighted) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(downweightedAnalysis.seasons[0].standardDeviation < evenAnalysis.seasons[0].standardDeviation)
    }
}

@Suite("SeriesAnalysisEngine — decline and consistency")
struct SeriesAnalysisEngineDeclineTests {
    private func analysis(_ episodes: [EpisodeMetric]) -> SeriesAnalysis? {
        guard case .analyzed(let value) = SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now) else {
            return nil
        }
        return value
    }

    @Test("a series that falls off after season 3 reports that boundary")
    func detectsDecline() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.8, 8.9, 8.7, 8.8])
        episodes += EpisodeFixtures.season(2, ratings: [8.9, 9.0, 8.8, 8.9])
        episodes += EpisodeFixtures.season(3, ratings: [8.7, 8.8, 8.6, 8.7])
        episodes += EpisodeFixtures.season(4, ratings: [7.4, 7.3, 7.5, 7.2])
        episodes += EpisodeFixtures.season(5, ratings: [7.1, 7.0, 7.2, 7.1])

        guard let result = analysis(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(result.declinePoint?.afterSeason == 3)
        #expect(result.declinePoint?.seasonsAfter == [4, 5])
        #expect((result.declinePoint?.drop ?? 0) > 0.5)
    }

    @Test("a consistently good series reports no decline")
    func noDeclineWhenSteady() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.5, 8.6, 8.4, 8.5])
        episodes += EpisodeFixtures.season(2, ratings: [8.6, 8.5, 8.7, 8.5])
        episodes += EpisodeFixtures.season(3, ratings: [8.5, 8.6, 8.5, 8.6])
        episodes += EpisodeFixtures.season(4, ratings: [8.6, 8.5, 8.6, 8.5])

        #expect(analysis(episodes)?.declinePoint == nil)
    }

    @Test("a dip in the final season alone is not a decline point")
    func requiresTwoSeasonsAfter() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.8, 8.9, 8.7, 8.8])
        episodes += EpisodeFixtures.season(2, ratings: [8.9, 8.8, 8.9, 8.8])
        episodes += EpisodeFixtures.season(3, ratings: [8.8, 8.9, 8.8, 8.7])
        episodes += EpisodeFixtures.season(4, ratings: [6.5, 6.4, 6.6, 6.5])

        // Only one season sits after the boundary, so the rule does not fire.
        #expect(analysis(episodes)?.declinePoint == nil)
    }

    @Test("a drop smaller than the threshold is not a decline point")
    func requiresMinimumDrop() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.5, 8.5, 8.5, 8.5])
        episodes += EpisodeFixtures.season(2, ratings: [8.5, 8.5, 8.5, 8.5])
        episodes += EpisodeFixtures.season(3, ratings: [8.3, 8.3, 8.3, 8.3])
        episodes += EpisodeFixtures.season(4, ratings: [8.2, 8.2, 8.2, 8.2])

        #expect(analysis(episodes)?.declinePoint == nil)
    }

    @Test("a single-season series has no decline point")
    func singleSeasonHasNoDecline() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.5, 7.5, 8.2, 8.1])
        #expect(analysis(episodes)?.declinePoint == nil)
    }

    @Test("a flat series is rated very steady")
    func ratesVerySteady() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.4, 8.5, 8.4, 8.5, 8.4, 8.5])
        #expect(analysis(episodes)?.consistency.rating == .verySteady)
    }

    @Test("a wildly swinging series is rated a rollercoaster")
    func ratesRollercoaster() {
        let episodes = EpisodeFixtures.season(1, ratings: [9.8, 5.5, 9.5, 5.2, 9.7, 5.0, 9.6, 5.4])
        #expect(analysis(episodes)?.consistency.rating == .rollercoaster)
    }

    @Test("consistency names the highest and lowest rated episodes")
    func consistencyCitesEvidence() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0, title: "One"),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 9.9, title: "Peak"),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 5.1, title: "Trough"),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.2, title: "Four")
        ]
        let consistency = analysis(episodes)?.consistency
        #expect(consistency?.highestRated?.title == "Peak")
        #expect(consistency?.lowestRated?.title == "Trough")
    }

    @Test("a decline is still detected when a season in between has no reliable data")
    func detectsDeclineAcrossAGapInReliableSeasons() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.8, 8.8, 8.8, 8.8])
        episodes += EpisodeFixtures.season(2, ratings: [8.9, 8.9, 8.9, 8.9])
        // Season 3 is entirely unreliable (below the vote floor), so it drops
        // out of `reliable` even though the aggregate share (16/20 = 80%)
        // still clears `minimumReliableShare`. The next season with reliable
        // data after boundary 2 is season 4, not season 3.
        episodes += EpisodeFixtures.season(3, ratings: [8.0, 8.0, 8.0, 8.0], votes: 3)
        episodes += EpisodeFixtures.season(4, ratings: [7.2, 7.2, 7.2, 7.2])
        episodes += EpisodeFixtures.season(5, ratings: [7.0, 7.0, 7.0, 7.0])

        guard let result = analysis(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(result.declinePoint?.afterSeason == 2)
        #expect(result.declinePoint?.seasonsAfter == [4, 5])
    }
}

@Suite("SeriesAnalysisEngine — standout episodes")
struct SeriesAnalysisEngineStandoutTests {
    private func analysis(_ episodes: [EpisodeMetric]) -> SeriesAnalysis? {
        guard case .analyzed(let value) = SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now) else {
            return nil
        }
        return value
    }

    @Test("an episode far above its season is essential")
    func findsEssentialEpisode() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.1),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 7.9),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 5, rating: 9.9, title: "Ozymandias"),
            EpisodeFixtures.episode(season: 1, number: 6, rating: 8.1)
        ]
        #expect(analysis(episodes)?.essentialEpisodes.map(\.title) == ["Ozymandias"])
    }

    @Test("an episode far below its season is skippable")
    func findsSkippableEpisode() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.1),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 7.9),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.0),
            EpisodeFixtures.episode(season: 1, number: 5, rating: 5.5, title: "Filler"),
            EpisodeFixtures.episode(season: 1, number: 6, rating: 8.1)
        ]
        #expect(analysis(episodes)?.skippableEpisodes.map(\.title) == ["Filler"])
    }

    @Test("a flat season has neither essential nor skippable episodes")
    func flatSeasonHasNoStandouts() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.1, 8.0, 7.9, 8.0])
        let result = analysis(episodes)
        #expect(result?.essentialEpisodes.isEmpty == true)
        #expect(result?.skippableEpisodes.isEmpty == true)
    }

    @Test("standouts are judged within their own season, not across the series")
    func judgesWithinSeason() {
        // Season 2 is uniformly weaker, but its own peak still stands out locally.
        var episodes = EpisodeFixtures.season(1, ratings: [9.0, 9.1, 8.9, 9.0, 9.1, 9.0])
        episodes += [
            EpisodeFixtures.episode(season: 2, number: 1, rating: 6.0),
            EpisodeFixtures.episode(season: 2, number: 2, rating: 6.1),
            EpisodeFixtures.episode(season: 2, number: 3, rating: 5.9),
            EpisodeFixtures.episode(season: 2, number: 4, rating: 6.0),
            EpisodeFixtures.episode(season: 2, number: 5, rating: 7.6, title: "Local Peak"),
            EpisodeFixtures.episode(season: 2, number: 6, rating: 6.1)
        ]
        let essential = analysis(episodes)?.essentialEpisodes.map(\.title) ?? []
        #expect(essential.contains("Local Peak"))
    }

    @Test("a season too short for a meaningful z-score yields no standouts")
    func skipsShortSeasons() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0, 8.0, 8.0])
        episodes += [
            EpisodeFixtures.episode(season: 2, number: 1, rating: 9.9),
            EpisodeFixtures.episode(season: 2, number: 2, rating: 5.0)
        ]
        let standouts = (analysis(episodes)?.essentialEpisodes ?? []) + (analysis(episodes)?.skippableEpisodes ?? [])
        #expect(standouts.allSatisfy { $0.seasonNumber != 2 })
    }

    @Test("standouts come back in season and episode order")
    func ordersStandouts() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0, 8.0])
        episodes.append(EpisodeFixtures.episode(season: 1, number: 6, rating: 9.8, title: "S1 peak"))
        episodes += EpisodeFixtures.season(2, ratings: [8.0, 8.0, 8.0, 8.0, 8.0])
        episodes.append(EpisodeFixtures.episode(season: 2, number: 6, rating: 9.8, title: "S2 peak"))

        #expect(analysis(episodes)?.essentialEpisodes.map(\.title) == ["S1 peak", "S2 peak"])
    }
}

@Suite("SeriesAnalysisEngine — verdicts and score")
struct SeriesAnalysisEngineVerdictTests {
    private func analysis(_ episodes: [EpisodeMetric]) -> SeriesAnalysis? {
        guard case .analyzed(let value) = SeriesAnalysisEngine.analyze(episodes: episodes, asOf: EpisodeFixtures.now) else {
            return nil
        }
        return value
    }

    @Test("a series that starts strong and settles down hooks early")
    func detectsStrongOpening() {
        var episodes = EpisodeFixtures.season(1, ratings: [9.2, 9.3, 9.1, 9.2, 9.3, 9.1])
        episodes += EpisodeFixtures.season(2, ratings: [8.0, 8.1, 7.9, 8.0, 8.1, 8.0])

        #expect(analysis(episodes)?.openingVerdict?.kind == .hooksEarly)
    }

    @Test("a series that starts weak and improves reports a slow start")
    func detectsSlowStart() {
        var episodes = EpisodeFixtures.season(1, ratings: [7.0, 7.1, 6.9, 7.0, 7.1, 7.0])
        episodes += EpisodeFixtures.season(2, ratings: [8.8, 8.9, 8.7, 8.8, 8.9, 8.8])
        episodes += EpisodeFixtures.season(3, ratings: [8.9, 9.0, 8.8, 8.9, 9.0, 8.9])

        let verdict = analysis(episodes)?.openingVerdict
        #expect(verdict?.kind == .slowStart)
        #expect(verdict?.improvesAtSeason == 2)
    }

    @Test("a level series reports an even opening")
    func detectsEvenOpening() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.4, 8.5, 8.4, 8.5, 8.4, 8.5])
        episodes += EpisodeFixtures.season(2, ratings: [8.5, 8.4, 8.5, 8.4, 8.5, 8.4])

        #expect(analysis(episodes)?.openingVerdict?.kind == .even)
    }

    @Test("the opening verdict names the episodes it looked at")
    func openingCitesEvidence() {
        var episodes = EpisodeFixtures.season(1, ratings: [9.2, 9.3, 9.1, 9.2, 9.3, 9.1])
        episodes += EpisodeFixtures.season(2, ratings: [8.0, 8.1, 7.9, 8.0, 8.1, 8.0])

        #expect(analysis(episodes)?.openingVerdict?.episodesConsidered.count == 6)
    }

    @Test("a series peaking in its final season ends strong")
    func detectsStrongEnding() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.1, 7.9, 8.0])
        episodes += EpisodeFixtures.season(2, ratings: [8.4, 8.5, 8.3, 8.4])
        episodes += EpisodeFixtures.season(3, ratings: [9.2, 9.3, 9.1, 9.2])

        let verdict = analysis(episodes)?.endingVerdict
        #expect(verdict?.kind == .endsStrong)
        #expect(verdict?.finalSeason == 3)
    }

    @Test("a series collapsing in its final season fades out")
    func detectsFadeOut() {
        var episodes = EpisodeFixtures.season(1, ratings: [9.0, 9.1, 8.9, 9.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.1, 9.2, 9.0, 9.1])
        episodes += EpisodeFixtures.season(3, ratings: [6.5, 6.4, 6.6, 6.5])

        let verdict = analysis(episodes)?.endingVerdict
        #expect(verdict?.kind == .fadesOut)
        #expect(verdict?.peakSeason == 2)
    }

    @Test("an ongoing series gets no ending verdict")
    func suppressesEndingWhileOngoing() {
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.1, 7.9, 8.0])
        episodes += EpisodeFixtures.season(2, ratings: [8.4, 8.5, 8.3, 8.4])
        episodes.append(
            EpisodeFixtures.episode(season: 3, number: 1, rating: 0, votes: 0, airDate: EpisodeFixtures.futureAirDate)
        )

        #expect(analysis(episodes)?.endingVerdict == nil)
    }

    @Test("a single-season series gets no ending verdict")
    func suppressesEndingForSingleSeason() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.1, 7.9, 8.0, 8.2, 8.1])
        #expect(analysis(episodes)?.endingVerdict == nil)
    }

    @Test("a great, steady, rising series scores higher than a mediocre erratic one")
    func scoresRelatively() {
        var great = EpisodeFixtures.season(1, ratings: [8.8, 8.9, 8.7, 8.8, 8.9, 8.8])
        great += EpisodeFixtures.season(2, ratings: [9.2, 9.3, 9.1, 9.2, 9.3, 9.2])

        var poor = EpisodeFixtures.season(1, ratings: [7.5, 5.0, 7.8, 4.9, 7.6, 5.1])
        poor += EpisodeFixtures.season(2, ratings: [6.0, 4.5, 6.2, 4.4, 6.1, 4.6])

        let greatScore = analysis(great)?.score.value ?? 0
        let poorScore = analysis(poor)?.score.value ?? 0
        #expect(greatScore > poorScore)
    }

    @Test("the score and its three components stay within 0...100")
    func scoreStaysInRange() {
        var episodes = EpisodeFixtures.season(1, ratings: [10.0, 10.0, 10.0, 10.0, 10.0, 10.0])
        episodes += EpisodeFixtures.season(2, ratings: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
        episodes += EpisodeFixtures.season(3, ratings: [10.0, 1.0, 10.0, 1.0, 10.0, 1.0])

        guard let score = analysis(episodes)?.score else {
            Issue.record("expected .analyzed")
            return
        }
        #expect((0...100).contains(score.value))
        #expect((0...100).contains(score.level))
        #expect((0...100).contains(score.consistency))
        #expect((0...100).contains(score.trajectory))
    }

    @Test("a series with a decline point and both verdicts round-trips through Codable")
    func fullAnalysisRoundTrips() throws {
        // Season 1 hooks hard (opening average 9.0), then the show settles at
        // 8.0 for seasons 2 and 3 — a drop big enough to register as a decline
        // point (>= 0.5) and, since the final season sits a full point below
        // the season-1 peak, a faded ending too. That gives us a fixture where
        // declinePoint, openingVerdict, and endingVerdict are all non-nil at
        // once, finally exercising their Codable conformance end to end.
        var episodes = EpisodeFixtures.season(1, ratings: [9.0, 9.0, 9.0, 9.0, 9.0, 9.0])
        episodes += EpisodeFixtures.season(2, ratings: [8.0, 8.0, 8.0, 8.0])
        episodes += EpisodeFixtures.season(3, ratings: [8.0, 8.0, 8.0, 8.0])

        guard let original = analysis(episodes) else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(original.declinePoint != nil)
        #expect(original.openingVerdict != nil)
        #expect(original.endingVerdict != nil)

        let data = try JSONEncoder().encode(SeriesAnalysisResult.analyzed(original))
        let decoded = try JSONDecoder().decode(SeriesAnalysisResult.self, from: data)

        guard case .analyzed(let decodedAnalysis) = decoded else {
            Issue.record("expected .analyzed")
            return
        }
        #expect(decodedAnalysis == original)
    }
}
