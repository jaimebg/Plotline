import SwiftUI

/// Directors and writers whose episodes rated above or below their own
/// seasons.
///
/// The wording is descriptive on purpose. The numbers show where a person's
/// episodes sit against the seasons they are in; they cannot show why, so no
/// string here says "because", "made", "behind" or "responsible".
struct CrewComparisonSection: View {
    let comparison: CrewComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Directors & Writers vs. Their Seasons")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(Self.methodNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !comparison.directorsAbove.isEmpty || !comparison.directorsBelow.isEmpty {
                group(title: "Directors", above: comparison.directorsAbove, below: comparison.directorsBelow)
            }

            if !comparison.writersAbove.isEmpty || !comparison.writersBelow.isEmpty {
                group(title: "Writers", above: comparison.writersAbove, below: comparison.writersBelow)
            }
        }
    }

    private func group(title: String, above: [CrewComparison.Entry], below: [CrewComparison.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            ForEach(above + below) { entry in
                row(entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private func row(_ entry: CrewComparison.Entry) -> some View {
        let subject = CrewEffectAnalyzer.subject(for: entry)
        let comparison = CrewEffectAnalyzer.comparison(for: entry)

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: entry.roundedDelta > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(subject)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(comparison)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subject): \(comparison)")
    }

    /// How the figure is made, and what it cannot say.
    static var methodNote: String {
        "Each episode's rating minus its own season's vote-weighted average, averaged over the episodes a person "
            + "is credited on. Only episodes with at least \(SeriesAnalysisEngine.minimumVotesPerEpisode) votes count; "
            + "a person needs \(CrewEffectAnalyzer.minimumEpisodes) or more, and anyone credited on every counted "
            + "episode of their seasons is left out, since they would be measured against themselves. "
            + "This describes how their episodes rated, not why."
    }
}
