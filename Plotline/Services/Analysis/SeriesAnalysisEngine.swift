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

    /// How many opening episodes the opening verdict weighs.
    static let openingEpisodeCount = 6

    /// How far the opening must sit from the rest to be worth calling out.
    static let openingVerdictThreshold = 0.4

    /// A final season within this much of the peak still counts as ending strong.
    static let endingStrongTolerance = 0.2

    /// A final season this far below the peak counts as fading out.
    static let endingFadeThreshold = 0.5

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
                openingVerdict: openingVerdict(from: reliable),
                endingVerdict: endingVerdict(from: seasons, isOngoing: isOngoing),
                score: plotlineScore(from: reliable),
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
    /// big enough, enough seasons follow it, and the series is still down when
    /// the run ends — a fall that starts here but recovers is not a decline.
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

            // ...and it must still be down at the end of the run, or a series
            // that dips and recovers reports a decline covering its own best season.
            let finalSeason = reliable.filter { $0.seasonNumber == seasons[seasons.count - 1] }
            guard averageBefore - weightedMean(finalSeason) >= minimumDeclineDrop else { continue }

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

    // MARK: - Opening

    /// Compares the opening run against everything after it, which is the
    /// question a viewer actually asks: is it worth pushing through the start?
    static func openingVerdict(from reliable: [EpisodeMetric]) -> OpeningVerdict? {
        let ordered = reliable.sorted {
            ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber)
        }
        guard ordered.count > openingEpisodeCount else { return nil }

        let opening = Array(ordered.prefix(openingEpisodeCount))
        let remainder = Array(ordered.dropFirst(openingEpisodeCount))
        // The season the opening run ends in. Safe to index: `ordered` is longer
        // than the opening run, which is what the guard above establishes.
        let openingSeason = ordered[openingEpisodeCount - 1].seasonNumber

        let openingAverage = weightedMean(opening)
        let remainderAverage = weightedMean(remainder)
        let delta = openingAverage - remainderAverage

        let kind: OpeningVerdict.Kind
        var improvesAtSeason: Int?

        if delta >= openingVerdictThreshold {
            kind = .hooksEarly
        } else if -delta >= openingVerdictThreshold {
            kind = .slowStart
            // Only a season that starts after the opening run can be where it
            // picks up. The opening's own season is the one just called weak,
            // and it stays in `remainder` whenever it runs longer than the
            // opening — the common case for a 10-episode first season.
            improvesAtSeason = firstSeasonClearing(openingAverage, after: openingSeason, in: remainder)
        } else {
            kind = .even
        }

        return OpeningVerdict(
            kind: kind,
            openingAverage: openingAverage,
            remainderAverage: remainderAverage,
            episodesConsidered: opening.map(reference),
            improvesAtSeason: improvesAtSeason
        )
    }

    /// The first season after `openingSeason` whose average clears `baseline` by
    /// the opening threshold. Nil when the series never gets there — including
    /// when it has no season after the opening at all.
    private static func firstSeasonClearing(
        _ baseline: Double,
        after openingSeason: Int,
        in episodes: [EpisodeMetric]
    ) -> Int? {
        let bySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        return bySeason.keys.sorted().first { season in
            season > openingSeason
                && weightedMean(bySeason[season] ?? []) - baseline >= openingVerdictThreshold
        }
    }

    // MARK: - Ending

    /// Only meaningful for a finished series with more than one season: an
    /// ongoing show has not ended, and a single season has no arc to land.
    static func endingVerdict(from seasons: [SeasonSummary], isOngoing: Bool) -> EndingVerdict? {
        guard !isOngoing, seasons.count > 1 else { return nil }
        guard let final = seasons.last,
              let peak = seasons.max(by: { $0.weightedAverage < $1.weightedAverage }) else {
            return nil
        }

        let shortfall = peak.weightedAverage - final.weightedAverage

        let kind: EndingVerdict.Kind
        if shortfall <= endingStrongTolerance {
            kind = .endsStrong
        } else if shortfall >= endingFadeThreshold {
            kind = .fadesOut
        } else {
            kind = .endsSteady
        }

        return EndingVerdict(
            kind: kind,
            finalSeason: final.seasonNumber,
            finalSeasonAverage: final.weightedAverage,
            peakSeason: peak.seasonNumber,
            peakSeasonAverage: peak.weightedAverage
        )
    }

    // MARK: - Plotline Score

    /// A 0-100 score built from three visible components, so the UI can show the
    /// breakdown rather than an unexplained number.
    ///
    /// - level: the weighted average, the single strongest signal, hence 60%.
    /// - consistency: how evenly the series holds that level.
    /// - trajectory: whether it climbs or slides across its run.
    static func plotlineScore(from reliable: [EpisodeMetric]) -> PlotlineScore {
        let mean = weightedMean(reliable)
        let level = clampToScore(mean * 10)

        let deviation = weightedStandardDeviation(reliable)
        let consistency = clampToScore(100 - deviation * 100)

        let ordered = reliable.sorted {
            ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber)
        }
        let third = max(1, ordered.count / 3)
        let opening = weightedMean(Array(ordered.prefix(third)))
        let closing = weightedMean(Array(ordered.suffix(third)))
        let trajectory = clampToScore(50 + (closing - opening) * 25)

        let combined = Double(level) * 0.6 + Double(consistency) * 0.2 + Double(trajectory) * 0.2

        return PlotlineScore(
            value: clampToScore(combined),
            level: level,
            consistency: consistency,
            trajectory: trajectory
        )
    }

    private static func clampToScore(_ value: Double) -> Int {
        Int(min(100, max(0, value)).rounded())
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
