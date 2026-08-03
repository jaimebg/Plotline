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

    /// How far from its season's mean an episode must sit to stand out.
    static let standoutZScoreThreshold = 1.5

    /// Below this many reliable episodes a season's spread is too noisy to
    /// draw a z-score from, so it contributes no standouts.
    static let minimumEpisodesForZScore = 4

    /// An episode must also sit this far from its season's mean in absolute
    /// terms. In a very flat season the standard deviation collapses, so a
    /// 0.1-point wobble clears the z-score threshold while meaning nothing.
    static let minimumStandoutDelta = 0.4

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
        let standouts = standoutEpisodes(from: reliable)

        return .analyzed(
            SeriesAnalysis(
                seasons: seasons,
                bestSeason: seasons.max(by: { $0.weightedAverage < $1.weightedAverage })?.seasonNumber,
                worstSeason: seasons.min(by: { $0.weightedAverage < $1.weightedAverage })?.seasonNumber,
                declinePoint: declinePoint(from: reliable),
                consistency: consistency(from: reliable),
                essentialEpisodes: standouts.essential,
                skippableEpisodes: standouts.skippable,
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

        for (index, boundary) in seasons.dropLast(minimumSeasonsAfterDecline).enumerated() {
            let before = reliable.filter { $0.seasonNumber <= boundary }
            let after = reliable.filter { $0.seasonNumber > boundary }
            guard !before.isEmpty, !after.isEmpty else { continue }

            let averageBefore = weightedMean(before)
            let averageAfter = weightedMean(after)
            guard averageBefore - averageAfter >= minimumDeclineDrop else { continue }

            // The fall has to START here. Look up the next season that actually
            // has reliable data rather than assuming season numbers are
            // contiguous — a whole season can drop out of `reliable` while the
            // aggregate reliability check still passes.
            let nextSeasonNumber = seasons[index + 1]
            let nextSeason = reliable.filter { $0.seasonNumber == nextSeasonNumber }
            guard averageBefore - weightedMean(nextSeason) >= minimumDeclineDrop else { continue }

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

    // MARK: - Standout Episodes

    /// Episodes that sit far from their own season's mean.
    ///
    /// Judged per season rather than across the series, so a strong episode of a
    /// weak season still registers — which is what a viewer deciding whether to
    /// skip ahead actually wants to know.
    static func standoutEpisodes(
        from reliable: [EpisodeMetric]
    ) -> (essential: [EpisodeReference], skippable: [EpisodeReference]) {
        var essential: [EpisodeReference] = []
        var skippable: [EpisodeReference] = []

        let bySeason = Dictionary(grouping: reliable, by: \.seasonNumber)

        for seasonNumber in bySeason.keys.sorted() {
            let episodes = bySeason[seasonNumber] ?? []
            guard episodes.count >= minimumEpisodesForZScore else { continue }

            let mean = weightedMean(episodes)
            let deviation = weightedStandardDeviation(episodes)
            guard deviation > 0 else { continue }

            for episode in episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }) {
                let delta = episode.rating - mean
                guard abs(delta) >= minimumStandoutDelta else { continue }

                let zScore = delta / deviation

                if zScore >= standoutZScoreThreshold {
                    essential.append(reference(episode))
                } else if zScore <= -standoutZScoreThreshold {
                    skippable.append(reference(episode))
                }
            }
        }

        return (essential, skippable)
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
