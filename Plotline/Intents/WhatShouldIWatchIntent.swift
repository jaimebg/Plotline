import AppIntents
import SwiftData

/// Siri intent that picks from the user's unwatched watchlist.
///
/// Among watchlist series with a bundled analysis it names the one with the
/// highest Plotline Score and gives the numbers behind it. Only when none has
/// one does it fall back to a random pick, and says that is what it is.
struct WhatShouldIWatchIntent: AppIntent {
    static var title: LocalizedStringResource = "What Should I Watch?"
    static var description = IntentDescription(
        "Name the unwatched series on your watchlist with the highest Plotline Score, or a random pick when none has been analysed"
    )
    static var openAppWhenRun = true

    @Dependency
    private var modelContainer: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = modelContainer.mainContext
        let allItems = (try? context.fetch(FetchDescriptor<WatchlistItem>())) ?? []

        // CloudKit can hold several records for one title until the app next
        // collapses them. Resolve each title's status the way the managers do,
        // so a title watched on another device is not suggested again.
        let candidates = DuplicateResolver.group(allItems, id: \.tmdbId, addedAt: \.addedAt)
            .filter { group in
                DuplicateResolver.mostAdvancedWatchStatus(
                    ([group.keeper] + group.duplicates).map(\.watchStatus)
                ) == "want_to_watch"
            }
            .map { group in
                WatchlistCandidate(
                    tmdbId: group.keeper.tmdbId,
                    title: group.keeper.title,
                    isSeries: group.keeper.isTVSeries,
                    voteAverage: group.keeper.voteAverage
                )
            }

        let store = DatasetStore.shared
        let pick = WatchlistPicker.pick(
            from: candidates,
            analysis: { store.entry(forTMDBId: $0)?.analysis }
        )
        return .result(dialog: IntentDialog(stringLiteral: WatchlistPicker.dialog(for: pick)))
    }
}

// MARK: - Picking

/// An unwatched watchlist title, reduced to what the pick needs.
nonisolated struct WatchlistCandidate: Equatable, Sendable {
    let tmdbId: Int
    let title: String
    let isSeries: Bool
    let voteAverage: Double
}

nonisolated enum WatchlistPick: Equatable, Sendable {
    /// The analysed series with the highest bundled Plotline Score, and how
    /// many analysed series it was compared against (itself included).
    case highestScore(WatchlistCandidate, analysis: SeriesAnalysis, comparedCount: Int)
    /// Nothing on the watchlist has a bundled analysis.
    case random(WatchlistCandidate)
    case empty
}

/// Pure picking and copy for `WhatShouldIWatchIntent`, testable without
/// SwiftData or the bundle.
nonisolated enum WatchlistPicker {
    /// - Parameters:
    ///   - analysis: the bundled analysis for a TMDB **series** id. Only
    ///     series are looked up: movie and TV ids are separate TMDB spaces, and
    ///     a movie sharing a series' number would otherwise borrow its score.
    ///   - randomIndex: which candidate a random pick takes, given the count.
    static func pick(
        from candidates: [WatchlistCandidate],
        analysis: (Int) -> SeriesAnalysis?,
        randomIndex: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) -> WatchlistPick {
        guard !candidates.isEmpty else { return .empty }

        let analysed = candidates
            .filter(\.isSeries)
            .compactMap { candidate in analysis(candidate.tmdbId).map { (candidate, $0) } }

        // Highest score wins; a tie goes to the title first alphabetically, so
        // the same watchlist always gets the same answer.
        let best = analysed.max { lhs, rhs in
            if lhs.1.score.value != rhs.1.score.value {
                return lhs.1.score.value < rhs.1.score.value
            }
            return lhs.0.title.localizedStandardCompare(rhs.0.title) == .orderedDescending
        }

        if let (candidate, analysis) = best {
            return .highestScore(candidate, analysis: analysis, comparedCount: analysed.count)
        }

        let index = min(max(randomIndex(candidates.count), 0), candidates.count - 1)
        return .random(candidates[index])
    }

    /// What Siri says. The score claim is scoped to the series Plotline has
    /// analysed — "highest on your watchlist" would take in titles it has no
    /// score for.
    static func dialog(for pick: WatchlistPick) -> String {
        switch pick {
        case .empty:
            return "Your watchlist is empty. Open Plotline to discover new titles!"

        case .highestScore(let candidate, let analysis, let comparedCount):
            let score = analysis.score
            let figures = "Plotline Score \(score.value) out of 100 (\(VerdictCopy.componentList(score)))"
            let basis = "from Plotline's bundled analysis of \(VerdictCopy.episodes(VerdictCopy.ratedEpisodeCount(analysis))) with enough votes to count"
            if comparedCount == 1 {
                return "The only series still to watch on your watchlist with a Plotline analysis is "
                    + "\(candidate.title): \(figures), \(basis)."
            }
            return "Highest Plotline Score among the \(comparedCount) analysed series still to watch on your watchlist: "
                + "\(candidate.title), at \(figures), \(basis)."

        case .random(let candidate):
            let kind = candidate.isSeries ? "series" : "movie"
            let rating = candidate.voteAverage > 0
                ? String(format: " rated %.1f on TMDB", candidate.voteAverage)
                : ""
            return "Nothing still to watch on your watchlist has a Plotline analysis, so this is a random pick: "
                + "\(candidate.title), a \(kind)\(rating)."
        }
    }
}
