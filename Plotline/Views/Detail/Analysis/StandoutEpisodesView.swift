import SwiftUI

/// Episodes that sit far from their own season's average, in either direction.
///
/// Judged within each season rather than across the run, so a high point of a
/// weaker season still shows up — which is what someone deciding whether to
/// skip ahead actually wants to know.
struct StandoutEpisodesView: View {
    /// Headings for the two groups. Internal so the honesty of the wording can
    /// be asserted directly rather than inspected by eye.
    static let essentialTitle = "Don't miss"
    static let weakestTitle = "Weakest of their season"

    let analysis: SeriesAnalysis

    private var hasAnything: Bool {
        !analysis.essentialEpisodes.isEmpty || !analysis.skippableEpisodes.isEmpty
    }

    var body: some View {
        if hasAnything {
            VStack(alignment: .leading, spacing: 12) {
                Text("Standout Episodes")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)

                if !analysis.essentialEpisodes.isEmpty {
                    group(
                        title: Self.essentialTitle,
                        caption: "Rated far above their own season",
                        episodes: analysis.essentialEpisodes,
                        tint: Color.chartHigh
                    )
                }

                if !analysis.skippableEpisodes.isEmpty {
                    group(
                        // Not "safe to skip". The engine establishes distance
                        // from a season's own average, nothing more: in a
                        // series averaging 9, its weakest hour still rates 8.3,
                        // and calling that skippable is advice the data does
                        // not support.
                        title: Self.weakestTitle,
                        caption: "Rated far below the rest of their own season",
                        episodes: analysis.skippableEpisodes,
                        tint: Color.chartLow
                    )
                }
            }
        }
    }

    private func group(
        title: String,
        caption: String,
        episodes: [EpisodeReference],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(episodes) { episode in
                HStack(spacing: 10) {
                    Text(episode.shortCode)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 52, alignment: .leading)

                    Text(episode.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(String(format: "%.1f", episode.rating))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(episode.shortCode), \(episode.title), rated \(String(format: "%.1f", episode.rating))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
