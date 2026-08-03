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

    /// A decline must cost at least this much to count as one.
    static let minimumDeclineDrop = 0.5

    /// And at least this many seasons must follow it, so a single weak final
    /// season reads as a weak ending rather than a decline.
    static let minimumSeasonsAfterDecline = 2

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
                declinePoint: declinePoint(from: reliable),
                consistency: consistency(from: reliable),
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

    // MARK: - Decline

    /// The season boundary that costs the series the most, provided the drop is
    /// big enough and enough seasons follow it to call the fall sustained.
    ///
    /// Deliberately simple: the result has to be explainable to a user in one
    /// sentence ("it falls off after season 5"), which rules out fitting curves.
    static func declinePoint(from reliable: [EpisodeMetric]) -> DeclinePoint? {
        let seasons = Set(reliable.map(\.seasonNumber)).sorted()
        guard seasons.count > minimumSeasonsAfterDecline else { return nil }

        var best: DeclinePoint?

        for boundary in seasons.dropLast(minimumSeasonsAfterDecline) {
            let before = reliable.filter { $0.seasonNumber <= boundary }
            let after = reliable.filter { $0.seasonNumber > boundary }
            guard !before.isEmpty, !after.isEmpty else { continue }

            let averageBefore = weightedMean(before)
            let averageAfter = weightedMean(after)
            guard averageBefore - averageAfter >= minimumDeclineDrop else { continue }

            // The fall has to START here. Without this, one catastrophic final
            // season drags the "after" average down at every earlier boundary
            // too, and the engine would report a decline three seasons before
            // anything actually went wrong.
            let nextSeason = reliable.filter { $0.seasonNumber == boundary + 1 }
            guard !nextSeason.isEmpty,
                  averageBefore - weightedMean(nextSeason) >= minimumDeclineDrop else { continue }

            let candidate = DeclinePoint(
                afterSeason: boundary,
                averageBefore: averageBefore,
                averageAfter: averageAfter,
                seasonsAfter: seasons.filter { $0 > boundary }
            )

            if candidate.drop > (best?.drop ?? 0) {
                best = candidate
            }
        }

        return best
    }

    // MARK: - Consistency

    static func consistency(from reliable: [EpisodeMetric]) -> Consistency {
        let deviation = weightedStandardDeviation(reliable)

        let rating: ConsistencyRating
        switch deviation {
        case ..<0.35: rating = .verySteady
        case ..<0.60: rating = .steady
        case ..<0.90: rating = .uneven
        default: rating = .rollercoaster
        }

        return Consistency(
            rating: rating,
            standardDeviation: deviation,
            highestRated: reliable.max(by: { $0.rating < $1.rating }).map(reference),
            lowestRated: reliable.min(by: { $0.rating < $1.rating }).map(reference)
        )
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
