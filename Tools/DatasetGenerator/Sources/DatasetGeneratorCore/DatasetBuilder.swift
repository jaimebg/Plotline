import Foundation

/// Turns analysed entries into the file the app ships.
enum DatasetBuilder {
    static func build(entries: [DatasetEntry], skipped: [SkippedSeries] = []) -> PlotlineDataset {
        let sorted = entries.sorted { $0.tmdbId < $1.tmdbId }
        // Sorted for the same reason as entries: so regenerating from
        // unchanged data reproduces an identical file.
        let sortedSkipped = skipped.sorted { $0.tmdbId < $1.tmdbId }

        return PlotlineDataset(
            version: PlotlineDataset.currentVersion,
            entries: sorted,
            lists: curatedLists(from: sorted),
            skipped: sortedSkipped
        )
    }

    /// A shelf with fewer titles than this is the same emptiness problem in
    /// miniature, so it is dropped rather than shipped looking broken.
    static let minimumListSize = 3

    /// Every list is a query over the analysis. Nothing here is hand-picked,
    /// which is the point: the lists are Plotline's own reading of the data, and
    /// they are exactly as defensible as the engine that produced them.
    ///
    /// Each predicate states what it can **prove** about a title, never merely
    /// what the analysis failed to find. The absence of evidence put nine shows
    /// whose own verdict was `fadesOut` on a shelf called "never declines", and
    /// a claim a title's own detail page contradicts is worse than no shelf.
    /// Lists carry ids only — the app owns the copy, keyed by `id`.
    static func curatedLists(from entries: [DatasetEntry]) -> [CuratedList] {
        let candidates: [(id: String, match: (DatasetEntry) -> Bool)] = [
            (
                // Positive evidence of holding a level: a run long enough to
                // have one, no decline, an ending that does not fade, steady
                // episode-to-episode quality, and a worst season that is not
                // the one it went out on.
                "never-decline",
                { entry in
                    let analysis = entry.analysis
                    return analysis.seasons.count >= 3
                        && analysis.declinePoint == nil
                        && analysis.endingVerdict?.kind != .fadesOut
                        && (analysis.consistency.rating == .verySteady || analysis.consistency.rating == .steady)
                        && analysis.worstSeason != analysis.seasons.last?.seasonNumber
                }
            ),
            (
                // A decline is direct evidence. The ending guard only stops the
                // one case where the same analysis would also earn a place on
                // "perfect-ending" — telling a user both stories at once.
                "falls-off",
                { entry in
                    entry.analysis.declinePoint != nil && entry.analysis.endingVerdict?.kind != .endsStrong
                }
            ),
            (
                // "Push through the start" is only worth saying when the
                // analysis can name the season it picks up at, and when the
                // series does not then fall apart anyway.
                "slow-burn",
                { entry in
                    entry.analysis.openingVerdict?.kind == .slowStart
                        && entry.analysis.openingVerdict?.improvesAtSeason != nil
                        && entry.analysis.declinePoint == nil
                }
            ),
            (
                // Ends at its peak, and did not slide on the way there.
                "perfect-ending",
                { entry in
                    entry.analysis.endingVerdict?.kind == .endsStrong && entry.analysis.declinePoint == nil
                }
            ),
            (
                // The one list that is its own definition: the shelf says the
                // episodes swing wildly, and that is precisely what the
                // consistency rating measures.
                "rollercoaster",
                { $0.analysis.consistency.rating == .rollercoaster }
            )
        ]

        return candidates.compactMap { candidate in
            let ids = entries.filter(candidate.match).map(\.tmdbId)
            guard ids.count >= minimumListSize else { return nil }

            return CuratedList(id: candidate.id, tmdbIds: ids)
        }
    }
}
