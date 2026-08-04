import SwiftUI

/// Episodes that sit far from their own season's average, in either direction.
///
/// Judged within each season rather than across the run, so a high point of a
/// weaker season still shows up — which is what someone deciding whether to
/// skip ahead actually wants to know.
struct StandoutEpisodesView: View {
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
                        title: "Don't miss",
                        caption: "Rated far above their own season",
                        episodes: analysis.essentialEpisodes,
                        tint: Color.chartHigh
                    )
                }

                if !analysis.skippableEpisodes.isEmpty {
                    group(
                        title: "Safe to skip",
                        caption: "Rated far below their own season",
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
