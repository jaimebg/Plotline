import Foundation

/// What a screen knows about a series' run status *now*, as opposed to when
/// the analysis on screen was computed.
///
/// App-side on purpose, and not one of the files shared with the dataset
/// generator: it describes a screen's load state, which the generator has no
/// notion of.
nonisolated enum CurrentSeriesStatus: Equatable, Sendable {
    /// TMDB's series details arrived. `hasEnded` is its status as
    /// `SeriesStatus` maps it: `true` ended, `false` returning or in
    /// production, `nil` a status it cannot place — which is never ended.
    case reported(hasEnded: Bool?)
    /// The details never arrived, so the current status is not known at all.
    case notLoaded

    /// The reported status, or nil when unknown or not loaded.
    var reportedHasEnded: Bool? {
        if case .reported(let hasEnded) = self { return hasEnded }
        return nil
    }
}

extension SeriesAnalysis {
    /// The ending verdict to show, given the series' current status. The one
    /// rule the detail screen, the share card and Compare all apply.
    ///
    /// An ending verdict is a claim about a finished run. The engine only
    /// writes one when told the series had ended, but an analysis can outlive
    /// that status — a bundled one computed before a revival, say — so:
    ///
    /// - With the details loaded, the verdict shows only when TMDB *currently*
    ///   reports the series as ended. Returning or an unplaceable status hides
    ///   it.
    /// - Without them, all there is to go on is the analysis itself. It shows
    ///   only when the analysis does not record the series as ongoing — which
    ///   an engine-written verdict never does, since it requires an ended
    ///   status — so an analysis that knew of more to come never carries an
    ///   ending onto the screen.
    nonisolated func visibleEndingVerdict(under status: CurrentSeriesStatus) -> EndingVerdict? {
        guard let endingVerdict else { return nil }
        switch status {
        case .reported(let hasEnded):
            return hasEnded == true ? endingVerdict : nil
        case .notLoaded:
            return isOngoing ? nil : endingVerdict
        }
    }
}
