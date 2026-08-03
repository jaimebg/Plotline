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

    /// Below this many reliable episodes there is nothing to say about
    /// consistency or trajectory, so the engine declines to speak at all.
    static let minimumReliableEpisodes = 3

    /// A season needs this many reliable episodes before it can be named best
    /// or worst, or carry the ending verdict.
    static let minimumEpisodesForSeasonVerdict = 3

    /// A decline must cost at least this much to count as one.
    static let minimumDeclineDrop = 0.4

    /// And at least this many seasons must follow it, so a single weak final
    /// season reads as a weak ending rather than a decline.
    static let minimumSeasonsAfterDecline = 2

    /// And at least this many must precede it. One season is a starting point,
    /// not an established level, so a fall measured against it says more about
    /// the length of the run than about the show.
    static let minimumSeasonsBeforeDecline = 2

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

    /// - Parameters:
    ///   - episodes: every episode the series lists, specials included.
    ///   - hasEnded: whether the series has finished, from TMDB's series-level
    ///     `status`. `nil` means unknown, which is not the same as "still
    ///     running": the episode list alone cannot tell a finished series from
    ///     one waiting between seasons, so an unknown status earns no ending
    ///     verdict. Kept as a parameter rather than fetched, so the engine stays
    ///     a pure function of its inputs.
    ///   - now: the reference date, explicit so the result never depends on the
    ///     clock.
    static func analyze(
        episodes: [EpisodeMetric],
        hasEnded: Bool? = nil,
        asOf now: Date = Date()
    ) -> SeriesAnalysisResult {
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

        // The share is a ratio, and a ratio cannot see sample size: one reliable
        // episode out of one aired is a perfect 100%. Consistency and trajectory
        // are meaningless on a sample that small, so the engine stops here.
        guard reliable.count >= minimumReliableEpisodes else {
            return .insufficientData(.notEnoughEpisodesToAnalyse)
        }

        let seasons = seasonSummaries(reliable: reliable, aired: aired)
        // Only seasons with enough reliable episodes may be named. A season
        // carried by a single episode is not the series' best or worst; it is
        // the season we know least about.
        let comparable = seasons.filter { $0.reliableEpisodeCount >= minimumEpisodesForSeasonVerdict }
        let standouts = standoutEpisodes(from: reliable)

        return .analyzed(
            SeriesAnalysis(
                seasons: seasons,
                bestSeason: comparable.max(by: { $0.weightedAverage < $1.weightedAverage })?.seasonNumber,
                worstSeason: comparable.min(by: { $0.weightedAverage < $1.weightedAverage })?.seasonNumber,
                declinePoint: declinePoint(from: reliable),
                consistency: consistency(from: reliable),
                essentialEpisodes: standouts.essential,
                skippableEpisodes: standouts.skippable,
                openingVerdict: openingVerdict(from: reliable),
                endingVerdict: endingVerdict(from: seasons, hasEnded: hasEnded),
                score: plotlineScore(from: reliable),
                isOngoing: isOngoing(mainRun, hasEnded: hasEnded, asOf: now)
            )
        )
    }

    // MARK: - Run Status

    /// Whether the series still has episodes to come.
    ///
    /// TMDB's series-level status is the authority. The episode list is only a
    /// fallback and a weak one: TMDB lists no episodes at all for a season that
    /// has not been announced, so a series resting between seasons looks
    /// finished. Only an episode with a real, future air date counts as
    /// evidence — a missing air date means TMDB does not know when (or whether)
    /// it airs, and silence is not a schedule.
    private static func isOngoing(_ mainRun: [EpisodeMetric], hasEnded: Bool?, asOf now: Date) -> Bool {
        if let hasEnded {
            return !hasEnded
        }
        return mainRun.contains { $0.airsAfter(now) }
    }

    // MARK: - Reliability

    private static func isReliable(_ episode: EpisodeMetric) -> Bool {
        episode.hasValidRating && episode.voteCount >= minimumVotesPerEpisode
    }

    // MARK: - Season Summaries

    /// - Parameters:
    ///   - reliable: the episodes the averages are built from.
    ///   - aired: every episode that has aired, reliable or not, so each summary
    ///     can report the coverage its average rests on ("2 of 10 episodes").
    private static func seasonSummaries(reliable: [EpisodeMetric], aired: [EpisodeMetric]) -> [SeasonSummary] {
        let airedCounts = Dictionary(grouping: aired, by: \.seasonNumber).mapValues(\.count)

        return Dictionary(grouping: reliable, by: \.seasonNumber)
            .sorted { $0.key < $1.key }
            .map { seasonNumber, episodes in
                // Pick from episodes in broadcast order, so two equally rated
                // episodes always resolve the same way. Left in input order the
                // winner would depend on how TMDB happened to sort its response,
                // and a live recomputation could disagree with the bundled
                // dataset over the same numbers.
                let ordered = episodes.sorted { $0.episodeNumber < $1.episodeNumber }

                return SeasonSummary(
                    seasonNumber: seasonNumber,
                    weightedAverage: weightedMean(episodes),
                    standardDeviation: weightedStandardDeviation(episodes),
                    reliableEpisodeCount: episodes.count,
                    airedEpisodeCount: airedCounts[seasonNumber] ?? episodes.count,
                    bestEpisode: ordered.max(by: { $0.rating < $1.rating }).map(reference),
                    worstEpisode: ordered.min(by: { $0.rating < $1.rating }).map(reference)
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
    private static func declinePoint(from reliable: [EpisodeMetric]) -> DeclinePoint? {
        let seasons = Set(reliable.map(\.seasonNumber)).sorted()
        guard seasons.count > minimumSeasonsAfterDecline else { return nil }

        var best: DeclinePoint?

        for (index, boundary) in seasons.dropLast(minimumSeasonsAfterDecline).enumerated() {
            // A single season is not a level to fall from. Without this, a
            // three-season show whose last two sit below its first is reported
            // as "declines after season 1" — a confident claim resting on one
            // season of baseline, which is ordinary variance in a short run.
            guard index + 1 >= minimumSeasonsBeforeDecline else { continue }

            let before = reliable.filter { $0.seasonNumber <= boundary }
            let after = reliable.filter { $0.seasonNumber > boundary }

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

    private static func consistency(from reliable: [EpisodeMetric]) -> Consistency {
        let deviation = weightedStandardDeviation(reliable)

        let rating: ConsistencyRating
        switch deviation {
        case ..<0.35: rating = .verySteady
        case ..<0.60: rating = .steady
        case ..<0.90: rating = .uneven
        default: rating = .rollercoaster
        }

        // As in `seasonSummaries`, ties resolve by broadcast order rather than
        // by whatever order the episodes arrived in.
        let ordered = reliable.sorted {
            ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber)
        }

        return Consistency(
            rating: rating,
            standardDeviation: deviation,
            highestRated: ordered.max(by: { $0.rating < $1.rating }).map(reference),
            lowestRated: ordered.min(by: { $0.rating < $1.rating }).map(reference)
        )
    }

    // MARK: - Standout Episodes

    /// Episodes that sit far from their own season's mean.
    ///
    /// Judged per season rather than across the series, so a strong episode of a
    /// weak season still registers — which is what a viewer deciding whether to
    /// skip ahead actually wants to know.
    private static func standoutEpisodes(
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
    private static func openingVerdict(from reliable: [EpisodeMetric]) -> OpeningVerdict? {
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

    /// Only meaningful for a series known to have ended, whose final season
    /// carries enough reliable episodes to judge and has at least one other
    /// judgeable season to be measured against.
    ///
    /// `hasEnded == nil` — an unknown status — is not good enough: an ending
    /// verdict is a claim about a completed work, and a series between seasons
    /// is indistinguishable from a finished one by its episode list alone.
    private static func endingVerdict(from seasons: [SeasonSummary], hasEnded: Bool?) -> EndingVerdict? {
        guard hasEnded == true else { return nil }

        // A season the analysis cannot speak for cannot be the peak either, and
        // a lone judgeable season would simply be its own peak — "ends on a
        // high" measured against nothing.
        let comparable = seasons.filter { $0.reliableEpisodeCount >= minimumEpisodesForSeasonVerdict }
        guard comparable.count > 1,
              let final = seasons.last,
              final.reliableEpisodeCount >= minimumEpisodesForSeasonVerdict,
              let peak = comparable.max(by: { $0.weightedAverage < $1.weightedAverage }) else {
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
    private static func plotlineScore(from reliable: [EpisodeMetric]) -> PlotlineScore {
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
    private static func weightedMean(_ episodes: [EpisodeMetric]) -> Double {
        let totalWeight = episodes.reduce(0) { $0 + $1.voteCount }
        guard totalWeight > 0 else { return 0 }

        let weightedSum = episodes.reduce(0.0) { $0 + $1.rating * Double($1.voteCount) }
        return weightedSum / Double(totalWeight)
    }

    private static func weightedStandardDeviation(_ episodes: [EpisodeMetric]) -> Double {
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

    private static func reference(_ episode: EpisodeMetric) -> EpisodeReference {
        EpisodeReference(
            id: episode.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            title: episode.title,
            rating: episode.rating
        )
    }
}
