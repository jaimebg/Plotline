import Foundation

/// Derives Plotline's own analysis from a series' episode ratings.
///
/// A pure function of its inputs: no networking, no UI, no stored state, and no
/// reliance on the current clock. That keeps it directly testable and lets the
/// Phase 3 dataset generator run the very same code the app runs.
enum SeriesAnalysisEngine {

    // MARK: - Thresholds
    //
    // Initial values, to be tuned against real data. The behaviour they guard
    // is not negotiable: the engine never emits a verdict it cannot support.

    /// An episode needs at least this many votes before it counts.
    static let minimumVotesPerEpisode = 10

    /// At least this share of the aired episodes must be reliable.
    static let minimumReliableShare = 0.6

    // MARK: - Entry Point

    static func analyze(episodes: [EpisodeMetric], asOf now: Date = Date()) -> SeriesAnalysisResult {
        // Season 0 is TMDB's specials bucket. Specials are not part of the main
        // run and would distort every average, so they never enter the analysis.
        let mainRun = episodes.filter { $0.seasonNumber > 0 }

        let aired = mainRun.filter { $0.hasAired(asOf: now) }
        guard !aired.isEmpty else {
            return .insufficientData(.noAiredEpisodes)
        }

        let reliable = aired.filter(isReliable)
        guard !reliable.isEmpty else {
            return .insufficientData(.noReliableEpisodes)
        }

        let share = Double(reliable.count) / Double(aired.count)
        guard share >= minimumReliableShare else {
            return .insufficientData(.tooFewReliableEpisodes)
        }

        let isOngoing = mainRun.contains { !$0.hasAired(asOf: now) }
        let seasons = seasonSummaries(from: reliable)

        return .analyzed(
            SeriesAnalysis(
                seasons: seasons,
                bestSeason: seasons.max(by: { $0.weightedAverage < $1.weightedAverage })?.seasonNumber,
                worstSeason: seasons.min(by: { $0.weightedAverage < $1.weightedAverage })?.seasonNumber,
                declinePoint: nil,
                consistency: Consistency(rating: .steady, standardDeviation: 0, highestRated: nil, lowestRated: nil),
                essentialEpisodes: [],
                skippableEpisodes: [],
                openingVerdict: nil,
                endingVerdict: nil,
                score: PlotlineScore(value: 0, level: 0, consistency: 0, trajectory: 0),
                isOngoing: isOngoing
            )
        )
    }

    // MARK: - Reliability

    static func isReliable(_ episode: EpisodeMetric) -> Bool {
        episode.hasValidRating && episode.voteCount >= minimumVotesPerEpisode
    }

    // MARK: - Season Summaries

    static func seasonSummaries(from reliable: [EpisodeMetric]) -> [SeasonSummary] {
        Dictionary(grouping: reliable, by: \.seasonNumber)
            .sorted { $0.key < $1.key }
            .map { seasonNumber, episodes in
                SeasonSummary(
                    seasonNumber: seasonNumber,
                    weightedAverage: weightedMean(episodes),
                    standardDeviation: weightedStandardDeviation(episodes),
                    reliableEpisodeCount: episodes.count,
                    bestEpisode: episodes.max(by: { $0.rating < $1.rating }).map(reference),
                    worstEpisode: episodes.min(by: { $0.rating < $1.rating }).map(reference)
                )
            }
    }

    // MARK: - Statistics

    /// Mean rating weighted by vote count, so a 9.8 backed by 12 votes cannot
    /// outweigh an 8.9 backed by 4,000.
    static func weightedMean(_ episodes: [EpisodeMetric]) -> Double {
        let totalWeight = episodes.reduce(0) { $0 + $1.voteCount }
        guard totalWeight > 0 else { return 0 }

        let weightedSum = episodes.reduce(0.0) { $0 + $1.rating * Double($1.voteCount) }
        return weightedSum / Double(totalWeight)
    }

    static func weightedStandardDeviation(_ episodes: [EpisodeMetric]) -> Double {
        let totalWeight = episodes.reduce(0) { $0 + $1.voteCount }
        guard totalWeight > 0, episodes.count > 1 else { return 0 }

        let mean = weightedMean(episodes)
        let variance = episodes.reduce(0.0) { partial, episode in
            let delta = episode.rating - mean
            return partial + delta * delta * Double(episode.voteCount)
        } / Double(totalWeight)

        return variance.squareRoot()
    }

    // MARK: - Helpers

    static func reference(_ episode: EpisodeMetric) -> EpisodeReference {
        EpisodeReference(
            id: episode.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            title: episode.title,
            rating: episode.rating
        )
    }
}
