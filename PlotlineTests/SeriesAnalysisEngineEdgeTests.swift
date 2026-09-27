import Foundation
import Testing
@testable import Plotline

/// The final season the verdicts measure against must be the season the run
/// actually ends on — not the last one that happened to have enough votes.
@Suite("SeriesAnalysisEngine — the true final season")
struct SeriesAnalysisEngineFinalSeasonTests {
    private func analysis(_ episodes: [EpisodeMetric], hasEnded: Bool? = nil) -> SeriesAnalysis? {
        guard case .analyzed(let value) = SeriesAnalysisEngine.analyze(
            episodes: episodes,
            hasEnded: hasEnded,
            asOf: EpisodeFixtures.now
        ) else {
            return nil
        }
        return value
    }

    /// Four low-vote episodes, so the season has aired but has no reliable
    /// episode and therefore no summary at all.
    private func unratedSeason(_ season: Int, count: Int = 4) -> [EpisodeMetric] {
        (1...count).map { EpisodeFixtures.episode(season: season, number: $0, rating: 6.0, votes: 2) }
    }

    @Test("an ended series whose final season has no reliable episode gets no ending verdict")
    func finalSeasonWithNoReliableEpisodes() {
        // Seasons 1 and 2 are solid; season 3 aired but nobody voted. The old
        // engine judged `seasons.last` — season 2 — and reported "Ends on a
        // high" for a show whose actual ending it knows nothing about.
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0, 8.0, 8.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.0, 9.0, 9.0, 9.0, 9.0, 9.0])
        episodes += unratedSeason(3)

        let result = analysis(episodes, hasEnded: true)
        #expect(result != nil, "16 aired, 12 reliable: 75% clears the share floor")
        #expect(result?.endingVerdict == nil)
        #expect(result?.seasons.map(\.seasonNumber) == [1, 2])
    }

    @Test("a thin final season is not replaced by the penultimate one")
    func thinFinalSeasonDoesNotHandTheEndingBack() {
        // Season 3 has two reliable episodes: known to exist, too thin to judge.
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.0, 9.0, 9.0, 9.0])
        episodes += [
            EpisodeFixtures.episode(season: 3, number: 1, rating: 5.0),
            EpisodeFixtures.episode(season: 3, number: 2, rating: 5.0)
        ]

        #expect(analysis(episodes, hasEnded: true)?.endingVerdict == nil)
    }

    @Test("a decline is not reported when the true final season is too thin to judge")
    func declineNeedsAJudgeableFinalSeason() {
        // Seasons 3 and 4 fall well below 1 and 2 — a textbook decline by the
        // judgeable seasons. But season 5 aired too, with two reliable
        // episodes, and "still down at the end of the run" is a claim about it.
        var episodes = EpisodeFixtures.season(1, ratings: [9.0, 9.0, 9.0, 9.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.0, 9.0, 9.0, 9.0])
        episodes += EpisodeFixtures.season(3, ratings: [7.5, 7.5, 7.5, 7.5])
        episodes += EpisodeFixtures.season(4, ratings: [7.5, 7.5, 7.5, 7.5])
        let withoutFinal = episodes
        episodes += [
            EpisodeFixtures.episode(season: 5, number: 1, rating: 9.2),
            EpisodeFixtures.episode(season: 5, number: 2, rating: 9.2)
        ]

        // The control: the same run ending at season 4 is a decline.
        #expect(analysis(withoutFinal)?.declinePoint?.afterSeason == 2)
        #expect(analysis(episodes)?.declinePoint == nil)
    }

    @Test("a decline still reaches a judgeable final season across a thin one in between")
    func declineAcrossAThinMiddleSeason() {
        var episodes = EpisodeFixtures.season(1, ratings: [9.0, 9.0, 9.0, 9.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.0, 9.0, 9.0, 9.0])
        episodes += EpisodeFixtures.season(3, ratings: [7.5, 7.5, 7.5, 7.5])
        episodes += [EpisodeFixtures.episode(season: 4, number: 1, rating: 7.5)]
        episodes += EpisodeFixtures.season(5, ratings: [7.5, 7.5, 7.5, 7.5])

        let decline = analysis(episodes)?.declinePoint
        #expect(decline?.afterSeason == 2)
        #expect(decline?.seasonsAfter == [3, 5])
    }
}

@Suite("SeriesAnalysisEngine — slow start and opening window")
struct SeriesAnalysisEngineOpeningTests {
    private func opening(_ episodes: [EpisodeMetric]) -> OpeningVerdict? {
        guard case .analyzed(let value) = SeriesAnalysisEngine.analyze(
            episodes: episodes,
            asOf: EpisodeFixtures.now
        ) else {
            return nil
        }
        return value.openingVerdict
    }

    @Test("a thin season cannot be where a slow start picks up")
    func improvementCannotLandOnAThinSeason() {
        // Season 2 has two reliable episodes at 9.0; season 3 is the first
        // judgeable season that clears the opening.
        var episodes = EpisodeFixtures.season(1, ratings: [7.0, 7.0, 7.0, 7.0, 7.0, 7.0])
        episodes += [
            EpisodeFixtures.episode(season: 2, number: 1, rating: 9.0),
            EpisodeFixtures.episode(season: 2, number: 2, rating: 9.0)
        ]
        episodes += EpisodeFixtures.season(3, ratings: [8.8, 8.8, 8.8, 8.8])

        let verdict = opening(episodes)
        #expect(verdict?.kind == .slowStart)
        #expect(verdict?.improvesAtSeason == 3)
    }

    @Test("an improvement that does not hold is not 'better from' that season")
    func nonSustainedImprovementIsNotNamed() {
        // Season 2 clears the opening; season 3 falls back to it; season 4
        // clears again. "Better from season 2" would cover season 3's relapse.
        var episodes = EpisodeFixtures.season(1, ratings: [7.0, 7.0, 7.0, 7.0, 7.0, 7.0])
        episodes += EpisodeFixtures.season(2, ratings: [8.8, 8.8, 8.8, 8.8])
        episodes += EpisodeFixtures.season(3, ratings: [7.0, 7.0, 7.0, 7.0])
        episodes += EpisodeFixtures.season(4, ratings: [8.9, 8.9, 8.9, 8.9, 8.9, 8.9])

        let verdict = opening(episodes)
        #expect(verdict?.kind == .slowStart)
        #expect(verdict?.improvesAtSeason == 4)
    }

    @Test("a relapse in the final season leaves no season to name")
    func relapseAtTheEndNamesNothing() {
        var episodes = EpisodeFixtures.season(1, ratings: [7.0, 7.0, 7.0, 7.0, 7.0, 7.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.0, 9.0, 9.0, 9.0, 9.0, 9.0])
        episodes += EpisodeFixtures.season(3, ratings: [9.0, 9.0, 9.0, 9.0, 9.0, 9.0])
        episodes += EpisodeFixtures.season(4, ratings: [7.1, 7.1, 7.1, 7.1])

        let verdict = opening(episodes)
        #expect(verdict?.kind == .slowStart)
        #expect(verdict?.improvesAtSeason == nil)
    }

    @Test("an improvement is not named when the final aired season is too thin to confirm it")
    func improvementNeedsAJudgeableFinalSeason() {
        var episodes = EpisodeFixtures.season(1, ratings: [7.0, 7.0, 7.0, 7.0, 7.0, 7.0])
        episodes += EpisodeFixtures.season(2, ratings: [9.0, 9.0, 9.0, 9.0, 9.0, 9.0])
        episodes += [EpisodeFixtures.episode(season: 3, number: 1, rating: 9.0)]

        let verdict = opening(episodes)
        #expect(verdict?.kind == .slowStart)
        #expect(verdict?.improvesAtSeason == nil)
    }

    @Test("the opening window skips an early episode without enough votes")
    func openingSkipsUnreliableEarlyEpisode() {
        // E2 has four votes. The opening run is the first six *reliable*
        // episodes, so it runs E1, E3...E7 — which the copy now says.
        var episodes = [EpisodeFixtures.episode(season: 1, number: 1, rating: 7.0)]
        episodes.append(EpisodeFixtures.episode(season: 1, number: 2, rating: 2.0, votes: 4))
        episodes += (3...10).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 7.0) }
        episodes += EpisodeFixtures.season(2, ratings: [7.0, 7.0, 7.0, 7.0])

        let verdict = opening(episodes)
        #expect(verdict?.episodesConsidered.map(\.episodeNumber) == [1, 3, 4, 5, 6, 7])
        // The 2.0 never reaches the average.
        #expect(verdict?.openingAverage == 7.0)
        #expect(verdict?.kind == .even)
    }
}

/// Thresholds are documented as inclusive ("at least"). These pin where each
/// boundary actually falls, including the one floating point moves.
@Suite("SeriesAnalysisEngine — threshold boundaries")
struct SeriesAnalysisEngineBoundaryTests {
    private func analyze(_ episodes: [EpisodeMetric], hasEnded: Bool? = nil) -> SeriesAnalysisResult {
        SeriesAnalysisEngine.analyze(episodes: episodes, hasEnded: hasEnded, asOf: EpisodeFixtures.now)
    }

    private func analysis(_ episodes: [EpisodeMetric]) -> SeriesAnalysis? {
        guard case .analyzed(let value) = analyze(episodes) else { return nil }
        return value
    }

    @Test("five votes make an episode reliable; four do not")
    func voteFloorIsInclusive() {
        let five = (1...3).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 5) }
        let four = (1...3).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 4) }

        #expect(analysis(five)?.seasons.first?.reliableEpisodeCount == 3)
        #expect(analyze(four) == .insufficientData(.noReliableEpisodes))
    }

    @Test("a reliable share of exactly 60% is enough")
    func reliableShareIsInclusive() {
        // 3 reliable of 5 aired.
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0])
        episodes += (4...5).map { EpisodeFixtures.episode(season: 1, number: $0, rating: 8.0, votes: 4) }

        #expect(analysis(episodes)?.seasons.first?.airedEpisodeCount == 5)
    }

    @Test("a drop of 0.4 counts as a decline")
    func declineDropIsInclusive() {
        // 8.5 → 8.1 computes as 0.40000000000000036: at the threshold, and in.
        var episodes = EpisodeFixtures.season(1, ratings: [8.5, 8.5, 8.5, 8.5])
        episodes += EpisodeFixtures.season(2, ratings: [8.5, 8.5, 8.5, 8.5])
        episodes += EpisodeFixtures.season(3, ratings: [8.1, 8.1, 8.1, 8.1])
        episodes += EpisodeFixtures.season(4, ratings: [8.1, 8.1, 8.1, 8.1])

        #expect(analysis(episodes)?.declinePoint?.afterSeason == 2)
    }

    @Test("a standout exactly 0.4 from its season's mean counts")
    func standoutDeltaIsInclusive() {
        // Mean 8.1, so E4 sits 0.4 above it (0.40000000000000036 computed),
        // at a z-score of 2.
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0, votes: 400),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.0, votes: 400),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 8.0, votes: 400),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.5, votes: 300)
        ]

        #expect(analysis(episodes)?.essentialEpisodes.map(\.shortCode) == ["S1E4"])
    }

    /// Recorded rather than endorsed. On paper this z-score is exactly 1.5 —
    /// three episodes carrying 900 votes against one carrying 400, so
    /// z = √(900/400) — and the threshold is inclusive. In floating point it
    /// computes as 1.4999999999999987 and misses. The engine adds no epsilon,
    /// so a paper-exact tie on the z-score does not count. If that ever
    /// changes, this test is the one to update.
    @Test("a z-score of 1.5 on paper computes just under and does not count")
    func standoutZScoreTieFallsUnder() {
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0, votes: 300),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.0, votes: 300),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 8.0, votes: 300),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 9.0, votes: 400)
        ]

        #expect(analysis(episodes)?.essentialEpisodes.isEmpty == true)
    }

    @Test("clearing both the z-score and the 0.4 floor by a hair counts")
    func standoutJustOverBothThresholds() {
        // Delta 0.40024, z 1.5000000000000016.
        let episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 8.0, votes: 300),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 8.0, votes: 300),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 8.0, votes: 300),
            EpisodeFixtures.episode(season: 1, number: 4, rating: 8.578125, votes: 400)
        ]

        #expect(analysis(episodes)?.essentialEpisodes.map(\.shortCode) == ["S1E4"])
    }

    @Test("an episode airing on the reference date has aired, and is not upcoming")
    func episodeAiringOnTheReferenceDate() {
        // `EpisodeFixtures.now` is 2020-01-01T00:00Z; the air date parses to
        // that same instant.
        var episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.0, 8.0, 8.0, 8.0])
        episodes.append(EpisodeFixtures.episode(season: 1, number: 6, rating: 0, votes: 0, airDate: "2020-01-01"))

        let result = analysis(episodes)
        #expect(result?.seasons.first?.airedEpisodeCount == 6)
        #expect(result?.isOngoing == false)
    }

    @Test("an unloaded season makes the engine refuse rather than judge a fragment")
    func unloadedSeasonIsRefused() {
        let episodes = EpisodeFixtures.season(1, ratings: [8.0, 8.1, 8.2, 8.0, 8.1, 8.2])
            + EpisodeFixtures.season(2, ratings: [8.0, 8.1, 8.2, 8.0, 8.1, 8.2])

        let refused = SeriesAnalysisEngine.analyze(
            episodes: episodes,
            unloadedSeasons: [3],
            asOf: EpisodeFixtures.now
        )
        #expect(refused == .insufficientData(.seasonsNotLoaded))

        // A missing specials bucket costs the main run nothing.
        let specialsOnly = SeriesAnalysisEngine.analyze(
            episodes: episodes,
            unloadedSeasons: [0],
            asOf: EpisodeFixtures.now
        )
        guard case .analyzed = specialsOnly else {
            Issue.record("expected .analyzed when only season 0 is missing")
            return
        }
    }

    @Test("the shared season average is the verdicts' average")
    func seasonAverageMatchesTheSummary() {
        var episodes = [
            EpisodeFixtures.episode(season: 1, number: 1, rating: 9.0, votes: 900),
            EpisodeFixtures.episode(season: 1, number: 2, rating: 6.0, votes: 100),
            EpisodeFixtures.episode(season: 1, number: 3, rating: 9.0, votes: 900)
        ]
        // Rated, but short of the vote floor: in an unweighted average this
        // would drag the figure down; in the verdicts' it does not count.
        episodes.append(EpisodeFixtures.episode(season: 1, number: 4, rating: 1.0, votes: 3))

        let summary = analysis(episodes)?.seasons.first?.weightedAverage
        let shared = SeriesAnalysisEngine.seasonAverage(of: episodes, asOf: EpisodeFixtures.now)
        #expect(summary != nil)
        #expect(shared == summary)
        #expect(SeriesAnalysisEngine.seasonAverage(of: [episodes[3]], asOf: EpisodeFixtures.now) == nil)
    }
}
