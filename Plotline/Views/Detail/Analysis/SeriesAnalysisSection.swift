import SwiftUI

/// Plotline's analysis of a series, or an honest silence.
///
/// Renders nothing at all when there is no result yet, and a reason when the
/// engine declined to judge. It never fills the gap with a softer verdict: the
/// engine's rule is that it says nothing it cannot support, and the UI keeps
/// that promise rather than papering over it.
struct SeriesAnalysisSection: View {
    let result: SeriesAnalysisResult?
    /// Seasons whose fetch failed, named when the engine refused for that reason.
    var failedSeasons: [Int] = []
    /// TMDB's series status and next scheduled air date, for the run-status row.
    var hasEnded: Bool?
    var nextEpisodeDate: Date?
    /// Offered when the refusal is one a retry can fix.
    var onRetry: (() -> Void)?

    var body: some View {
        switch result {
        case .analyzed(let analysis):
            VStack(alignment: .leading, spacing: 16) {
                PlotlineScoreCard(score: analysis.score)
                SeriesVerdictsView(analysis: analysis, hasEnded: hasEnded, nextEpisodeDate: nextEpisodeDate)
            }

        case .insufficientData(let reason):
            unavailable(reason: reason)

        case nil:
            EmptyView()
        }
    }

    private func unavailable(reason: InsufficientDataReason) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title(for: reason))
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            Text(explanation(for: reason))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if reason == .seasonsNotLoaded, let onRetry {
                Button("Try Again", action: onRetry)
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // `.contain` rather than `.combine` so the Try Again button stays
        // reachable on its own.
        .accessibilityElement(children: .contain)
    }

    /// One message per reason. A single catch-all would be wrong for at least
    /// one of them: "nothing has aired" is a different fact from "too few
    /// ratings", and saying the wrong one is exactly the failure this app is
    /// built to avoid.
    private func title(for reason: InsufficientDataReason) -> String {
        switch reason {
        case .noAiredEpisodes: return "Nothing Has Aired Yet"
        case .seasonsNotLoaded: return "Some Seasons Didn't Load"
        case .noReliableEpisodes, .tooFewReliableEpisodes, .notEnoughEpisodesToAnalyse: return "Not Enough Ratings Yet"
        }
    }

    private func explanation(for reason: InsufficientDataReason) -> String {
        switch reason {
        case .noAiredEpisodes:
            return "We'll analyse this series once its episodes start airing."
        case .noReliableEpisodes:
            return "Its episodes haven't collected enough ratings for us to say anything we'd stand behind."
        case .tooFewReliableEpisodes:
            return "Only a small share of its episodes carry enough ratings to judge, so we'd rather not guess at the rest."
        case .notEnoughEpisodesToAnalyse:
            return "There are too few rated episodes here to draw any conclusion from."
        case .seasonsNotLoaded:
            return Self.seasonsNotLoadedExplanation(failedSeasons)
        }
    }

    /// One line for the grid, where some seasons did load: which ones did not.
    static func seasonsNotLoadedNotice(_ seasons: [Int]) -> String {
        let sorted = seasons.sorted()
        switch sorted.count {
        case 0:
            return "Some seasons couldn't be loaded."
        case 1:
            return "Season \(sorted[0]) couldn't be loaded."
        default:
            let head = sorted.dropLast().map(String.init).joined(separator: ", ")
            return "Seasons \(head) and \(sorted[sorted.count - 1]) couldn't be loaded."
        }
    }

    /// Names the gap, so the refusal reads as a fact about this fetch rather
    /// than about the series.
    static func seasonsNotLoadedExplanation(_ seasons: [Int]) -> String {
        let sorted = seasons.sorted()
        switch sorted.count {
        case 0:
            return "Some of its seasons couldn't be loaded, and an analysis without them would be a guess."
        case 1:
            return "We couldn't load season \(sorted[0]), and an analysis without it would be a guess."
        default:
            let head = sorted.dropLast().map(String.init).joined(separator: ", ")
            return "We couldn't load seasons \(head) and \(sorted[sorted.count - 1]), "
                + "and an analysis without them would be a guess."
        }
    }
}
