import Foundation

/// Turns analysed entries into the file the app ships.
enum DatasetBuilder {
    static func build(entries: [DatasetEntry]) -> PlotlineDataset {
        let sorted = entries.sorted { $0.tmdbId < $1.tmdbId }

        return PlotlineDataset(
            version: PlotlineDataset.currentVersion,
            entries: sorted,
            lists: curatedLists(from: sorted)
        )
    }

    /// Every list is a query over the analysis. Nothing here is hand-picked,
    /// which is the point: the lists are Plotline's own reading of the data, and
    /// they are exactly as defensible as the engine that produced them.
    static func curatedLists(from entries: [DatasetEntry]) -> [CuratedList] {
        let candidates: [(id: String, title: String, subtitle: String, match: (DatasetEntry) -> Bool)] = [
            (
                "never-decline",
                "Series que nunca decaen",
                "Mantienen el nivel de principio a fin",
                { $0.analysis.declinePoint == nil && $0.analysis.consistency.rating != .rollercoaster }
            ),
            (
                "falls-off",
                "Las que se hunden",
                "Empiezan fuerte y no aguantan",
                { $0.analysis.declinePoint != nil }
            ),
            (
                "slow-burn",
                "Remontadas",
                "Arrancan flojas y mejoran mucho",
                { $0.analysis.openingVerdict?.kind == .slowStart }
            ),
            (
                "perfect-ending",
                "Cierres perfectos",
                "Terminan en su mejor momento",
                { $0.analysis.endingVerdict?.kind == .endsStrong }
            ),
            (
                "rollercoaster",
                "Montañas rusas",
                "Episodios brillantes junto a otros olvidables",
                { $0.analysis.consistency.rating == .rollercoaster }
            )
        ]

        return candidates.compactMap { candidate in
            let ids = entries.filter(candidate.match).map(\.tmdbId)
            // An empty list on a shelf is exactly the emptiness this whole
            // project is trying to remove from the app, so never emit one.
            guard !ids.isEmpty else { return nil }

            return CuratedList(
                id: candidate.id,
                title: candidate.title,
                subtitle: candidate.subtitle,
                tmdbIds: ids
            )
        }
    }
}
