import Foundation

/// How each credited director's and writer's episodes rated against their own
/// seasons.
///
/// Descriptive, never causal: a positive number says their episodes rated
/// above the seasons they sit in, not that they are why. The copy built on
/// this must keep to that.
nonisolated struct CrewComparison: Hashable, Sendable {
    enum Role: String, Hashable, Sendable {
        case director
        case writer
    }

    struct Entry: Hashable, Sendable, Identifiable {
        var id: String { "\(role.rawValue):\(name)" }

        let name: String
        let role: Role
        /// Mean, over the person's reliable episodes, of each episode's rating
        /// minus its own season's vote-weighted average.
        let meanDelta: Double
        /// `meanDelta` to one decimal — the figure shown, and the one that
        /// decides above or below, so "+0.0" can never appear.
        let roundedDelta: Double
        let episodeCount: Int
        let seasonCount: Int
    }

    let directorsAbove: [Entry]
    let directorsBelow: [Entry]
    let writersAbove: [Entry]
    let writersBelow: [Entry]

    var isEmpty: Bool {
        directorsAbove.isEmpty && directorsBelow.isEmpty && writersAbove.isEmpty && writersBelow.isEmpty
    }
}

/// Compares directors and writers with the seasons they worked on.
///
/// App-only and pure Foundation: no networking, no clock unless one is passed,
/// no UI. Not shared with the dataset generator — the bundled dataset carries
/// no episodes, so there is nothing for it to run on there.
nonisolated enum CrewEffectAnalyzer {
    /// A person needs at least this many reliable episodes to be listed. Two
    /// episodes is an anecdote.
    static let minimumEpisodes = 3

    /// How many people are shown on each side, per role.
    static let maximumPerSide = 3

    /// - Parameters:
    ///   - episodes: every loaded episode, any season. Specials, unaired
    ///     episodes and episodes without enough votes are ignored, by the
    ///     engine's own reliability rule.
    ///   - now: explicit so the result never depends on the clock.
    static func compare(episodes: [EpisodeMetric], asOf now: Date = Date()) -> CrewComparison {
        let reliable = episodes.filter {
            $0.seasonNumber > 0 && $0.hasAired(asOf: now) && SeriesAnalysisEngine.isReliable($0)
        }
        let bySeason = Dictionary(grouping: reliable, by: \.seasonNumber)
        // The same definition the verdicts, chart and grid use.
        let seasonAverages = bySeason.compactMapValues { SeriesAnalysisEngine.seasonAverage(of: $0, asOf: now) }

        let directors = entries(role: .director, credits: \.directors, reliable: reliable, averages: seasonAverages)
        let writers = entries(role: .writer, credits: \.writers, reliable: reliable, averages: seasonAverages)

        return CrewComparison(
            directorsAbove: above(directors),
            directorsBelow: below(directors),
            writersAbove: above(writers),
            writersBelow: below(writers)
        )
    }

    /// Every person who qualifies for one role, above and below together.
    static func entries(
        role: CrewComparison.Role,
        credits: KeyPath<EpisodeMetric, [String]?>,
        reliable: [EpisodeMetric],
        averages: [Int: Double]
    ) -> [CrewComparison.Entry] {
        // Only episodes whose crew is known for this role. An episode with no
        // crew data is not evidence that nobody directed it.
        let known = reliable.filter { $0[keyPath: credits] != nil }
        let knownPerSeason = Dictionary(grouping: known, by: \.seasonNumber).mapValues(\.count)

        var deltas: [String: [(season: Int, delta: Double)]] = [:]
        for episode in known {
            guard let average = averages[episode.seasonNumber] else { continue }
            for name in Set(episode[keyPath: credits] ?? []) {
                deltas[name, default: []].append((episode.seasonNumber, episode.rating - average))
            }
        }

        return deltas.compactMap { name, values -> CrewComparison.Entry? in
            guard values.count >= minimumEpisodes else { return nil }

            // Someone credited on every counted episode of every season they
            // worked on is being compared with an average made of their own
            // episodes. The result is ~0 by construction, or a weighting
            // artefact, and says nothing about them.
            let perSeason = Dictionary(grouping: values, by: \.season).mapValues(\.count)
            let isWholeOfTheirSeasons = perSeason.allSatisfy { season, count in
                count >= (knownPerSeason[season] ?? 0)
            }
            guard !isWholeOfTheirSeasons else { return nil }

            let mean = values.reduce(0) { $0 + $1.delta } / Double(values.count)
            return CrewComparison.Entry(
                name: name,
                role: role,
                meanDelta: mean,
                roundedDelta: roundedToTenth(mean),
                episodeCount: values.count,
                seasonCount: perSeason.count
            )
        }
    }

    /// One decimal, halves away from zero — the figure the copy prints.
    static func roundedToTenth(_ value: Double) -> Double {
        let rounded = (value * 10).rounded(.toNearestOrAwayFromZero) / 10
        return rounded == 0 ? 0 : rounded
    }

    private static func above(_ entries: [CrewComparison.Entry]) -> [CrewComparison.Entry] {
        Array(
            entries
                .filter { $0.roundedDelta > 0 }
                // Largest first; ties to the larger sample, then by name.
                .sorted { ($1.roundedDelta, $1.episodeCount, $0.name) < ($0.roundedDelta, $0.episodeCount, $1.name) }
                .prefix(maximumPerSide)
        )
    }

    private static func below(_ entries: [CrewComparison.Entry]) -> [CrewComparison.Entry] {
        Array(
            entries
                .filter { $0.roundedDelta < 0 }
                // Most negative first; ties to the larger sample, then by name.
                .sorted { ($0.roundedDelta, $1.episodeCount, $0.name) < ($1.roundedDelta, $0.episodeCount, $1.name) }
                .prefix(maximumPerSide)
        )
    }

    // MARK: - Copy

    /// "Episodes directed by Vince Gilligan".
    static func subject(for entry: CrewComparison.Entry) -> String {
        switch entry.role {
        case .director: "Episodes directed by \(entry.name)"
        case .writer: "Episodes written by \(entry.name)"
        }
    }

    /// "+0.6 vs. their season's average (5 episodes)". Plural "seasons'
    /// averages" when the episodes span more than one season, since each is
    /// measured against its own.
    static func comparison(for entry: CrewComparison.Entry) -> String {
        let delta = String(format: "%+.1f", entry.roundedDelta)
        let against = entry.seasonCount == 1 ? "their season's average" : "their seasons' averages"
        let episodes = entry.episodeCount == 1 ? "episode" : "episodes"
        return "\(delta) vs. \(against) (\(entry.episodeCount) \(episodes))"
    }
}
