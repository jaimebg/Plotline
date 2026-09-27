import Foundation

/// How a screen that already shows an analysis folds a fresh season fetch
/// into it: merge what loaded, name what did not, rerun the engine, and let
/// the result through only when it is at least as complete as what is shown.
///
/// Shared by every screen that runs the engine on live data — the detail
/// screen and Compare — so the two can never apply subtly different rules to
/// the same series. Pure and static: no network, no clock, no stored state.
///
/// Deliberately **not** one of the files shared with the dataset generator:
/// it knows about `SeasonFetchResult`, which is app-side.
nonisolated enum LiveSeriesAnalysis {

    /// A season fetch merged into the episodes already held.
    struct Merged: Equatable {
        var episodesBySeason: [Int: [EpisodeMetric]]
        /// Seasons still missing after the merge. A season that failed this
        /// time but loaded on an earlier attempt is not missing.
        var failedSeasons: [Int]
    }

    /// Merges a fetch into what is already held.
    ///
    /// A retry that fails outright must not wipe seasons an earlier attempt
    /// did load, so this merges rather than replaces.
    static func merge(_ fetched: SeasonFetchResult, into held: [Int: [EpisodeMetric]]) -> Merged {
        var episodes = held
        episodes.merge(fetched.episodesBySeason) { _, fresh in fresh }
        return Merged(
            episodesBySeason: episodes,
            failedSeasons: fetched.failedSeasons.filter { episodes[$0] == nil }
        )
    }

    /// The fresh result that should replace `current`, or nil to keep it.
    ///
    /// Nil too when no episode is held at all: there is nothing to analyse,
    /// and an empty fetch is not evidence of anything.
    ///
    /// Seasons that failed go to the engine as well as staying out of the
    /// episode list, so a partial fetch comes back as a refusal naming the
    /// gap rather than as an analysis of whatever happened to load.
    ///
    /// - Parameters:
    ///   - hasEnded: TMDB's series status as `SeriesStatus` maps it, `nil` for
    ///     unknown. Passed through untouched: the engine withholds the ending
    ///     verdict for an unknown status rather than assuming either way.
    ///   - now: explicit so the result never depends on the clock.
    static func replacement(
        for current: SeriesAnalysisResult?,
        episodesBySeason: [Int: [EpisodeMetric]],
        failedSeasons: [Int],
        hasEnded: Bool?,
        asOf now: Date
    ) -> SeriesAnalysisResult? {
        let episodes = episodesBySeason.values.flatMap { $0 }
        guard !episodes.isEmpty else { return nil }

        let fresh = SeriesAnalysisEngine.analyze(
            episodes: episodes,
            hasEnded: hasEnded,
            unloadedSeasons: failedSeasons,
            asOf: now
        )

        return shouldReplace(current, with: fresh, failedSeasons: failedSeasons) ? fresh : nil
    }

    /// Whether a freshly computed analysis may replace the one on screen.
    ///
    /// A season that fails is absent from the episodes (it is listed in
    /// `failedSeasons`), and a failed detail request leaves the season count
    /// at its default — so a flaky connection can hand back a single cached
    /// season for a five-season series and report no failure at all.
    /// Replacing a complete analysis with that would show a fragment, or "Not
    /// Enough Ratings Yet" for a series whose full analysis is sitting in the
    /// app bundle.
    ///
    /// So an analysis already on screen — bundled or from an earlier live
    /// load — is only replaced by a fresh one that is itself a full analysis,
    /// came from a fetch in which no season failed, and covers every season
    /// the existing one does. Comparing season *counts* was not enough: seasons
    /// 1, 2, 4 against a bundled 1, 2, 3 is the same count and a different run.
    ///
    /// With nothing worth protecting on screen (no analysis, or a refusal),
    /// the fresh result always goes through — including the engine's own
    /// refusal for a partial fetch, which is the honest thing to show.
    static func shouldReplace(
        _ current: SeriesAnalysisResult?,
        with fresh: SeriesAnalysisResult,
        failedSeasons: [Int]
    ) -> Bool {
        guard case .analyzed(let existing)? = current else { return true }
        guard failedSeasons.isEmpty, case .analyzed(let live) = fresh else { return false }

        let liveSeasons = Set(live.seasons.map(\.seasonNumber))
        return liveSeasons.isSuperset(of: existing.seasons.map(\.seasonNumber))
    }
}
