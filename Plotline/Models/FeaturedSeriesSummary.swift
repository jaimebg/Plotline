import Foundation

/// The words on Discover's featured card. Every string comes from a helper the
/// detail screen or share card already uses, so the card can say no more than
/// they do.
struct FeaturedSeriesSummary: Equatable {
    let title: String
    let score: Int
    let seasonAverages: [Double]
    let verdict: String
    let basis: String

    init(entry: DatasetEntry) {
        let analysis = entry.analysis
        title = entry.name
        score = analysis.score.value
        seasonAverages = analysis.seasons.map(\.weightedAverage)
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
