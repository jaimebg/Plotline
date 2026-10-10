import Foundation

/// The words on Discover's featured card. Every string comes from a helper the
/// detail screen or share card already uses, so the card can say no more than
/// they do.
struct FeaturedSeriesSummary: Equatable {
    /// One analysed season: its own number and its weighted average. The
    /// number travels with the average because the analysed seasons can skip
    /// one (Blue Bloods runs 1–11, then 14), and a label taken from the
    /// position would name a season that was never analysed.
    nonisolated struct SeasonPoint: Equatable, Sendable {
        let season: Int
        let average: Double

        var axisLabel: String { "S\(season)" }
    }

    let title: String
    let score: Int
    let seasonPoints: [SeasonPoint]
    let verdict: String
    let basis: String

    init(entry: DatasetEntry) {
        let analysis = entry.analysis
        title = entry.name
        score = analysis.score.value
        seasonPoints = analysis.seasons.map { SeasonPoint(season: $0.seasonNumber, average: $0.weightedAverage) }
        verdict = Self.verdict(for: analysis)
        basis = VerdictCardContent.basis(for: analysis)
    }

    /// Decline, then an ending the status gate lets through, then consistency.
    /// The gate reads `.notLoaded`: Discover has only the bundled status, under
    /// which a series listed as returning never shows an ending.
    static func verdict(for analysis: SeriesAnalysis) -> String {
        if let decline = analysis.declinePoint {
            return SeriesVerdictsView.declineTitle(decline)
        }
        if let ending = analysis.visibleEndingVerdict(under: .notLoaded) {
            return SeriesVerdictsView.endingTitle(ending)
        }
        return SeriesVerdictsView.consistencyTitle(analysis.consistency.rating)
    }
}
