import SwiftUI

/// Plotline's analysis of a series, or an honest silence.
///
/// Renders nothing at all when there is no result yet, and a reason when the
/// engine declined to judge. It never fills the gap with a softer verdict: the
/// engine's rule is that it says nothing it cannot support, and the UI keeps
/// that promise rather than papering over it.
struct SeriesAnalysisSection: View {
    let result: SeriesAnalysisResult?

    var body: some View {
        switch result {
        case .analyzed(let analysis):
            VStack(alignment: .leading, spacing: 16) {
                PlotlineScoreCard(score: analysis.score)
                SeriesVerdictsView(analysis: analysis)
                StandoutEpisodesView(analysis: analysis)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title(for: reason)). \(explanation(for: reason))")
    }

    /// One message per reason. A single catch-all would be wrong for at least
    /// one of them: "nothing has aired" is a different fact from "too few
    /// ratings", and saying the wrong one is exactly the failure this app is
    /// built to avoid.
    private func title(for reason: InsufficientDataReason) -> String {
        switch reason {
        case .noAiredEpisodes: return "Nothing Has Aired Yet"
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
        }
    }
}
