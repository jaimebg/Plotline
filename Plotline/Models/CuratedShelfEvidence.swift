import Foundation

/// The one line a "See all" row shows for why a series is on a shelf: the
/// existing verdict string for the field that shelf's predicate tests.
enum CuratedShelfEvidence {
    static func line(forShelf base: String, analysis: SeriesAnalysis) -> String? {
        switch base {
        case "falls-off":
            return analysis.declinePoint.map(SeriesVerdictsView.declineTitle)
        case "perfect-ending":
            return analysis.visibleEndingVerdict(under: .notLoaded).map(SeriesVerdictsView.endingTitle)
        case "slow-burn":
            return analysis.openingVerdict.map(SeriesVerdictsView.openingTitle)
        case "rollercoaster":
            return SeriesVerdictsView.consistencyTitle(analysis.consistency.rating)
        case "never-decline":
            // The predicate tests the decline point, not consistency.
            return analysis.declinePoint == nil ? AnalysisTrait.noDeclineFound.label : nil
        default:
            return nil
        }
    }
}
